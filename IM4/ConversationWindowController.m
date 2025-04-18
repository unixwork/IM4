/*
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
 *
 * Copyright 2024 Olaf Wintermann. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */


#import "ConversationWindowController.h"
#import "AppDelegate.h"

#include "xmpp.h"
#include "regexreplace.h"

static NSString* escape_input(NSString *input) {
    NSMutableString *inputEscaped = [[NSMutableString alloc] init];
    [input enumerateSubstringsInRange:NSMakeRange(0, [input length])  options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *outStop) {

        const char *s = [substring UTF8String];
        switch(*s) {
            default: {
                
                [inputEscaped appendString:substring];
                break;
            }
            case '<': {
                [inputEscaped appendString:@"&lt;"];
                break;
            }
            case '>': {
                [inputEscaped appendString:@"&gt;"];
                break;
            }
            case '&' : {
                [inputEscaped appendString:@"&amp;"];
                break;
            }
            case '"': {
                [inputEscaped appendString:@"&quot;"];
                break;
            }
            case '\'': {
                [inputEscaped appendString:@"&#39;"];
                break;
            }
        }
    }];
    
    return inputEscaped;
}

static NSString* convert_urls_to_links(NSString *input, BOOL escape) {
    NSMutableString *inputEscaped = [[NSMutableString alloc] init];
    
    NSString *regex = @"https?:\\/\\/{1}[a-zA-Z0-9u00a1-\\uffff0-]{2,}\\.[a-zA-Z0-9u00a1-\\uffff0-]{2,}(\\S*)";
    
    NSRange url = [input rangeOfString:regex options:NSRegularExpressionSearch];
    while(url.location != NSNotFound) {
        NSString *urlStr = [input substringWithRange:url];
        
        NSString *pre = [input substringToIndex:url.location];
        [inputEscaped appendString:escape?escape_input(pre):pre];
        [inputEscaped appendString:@"<a href=\""];
        [inputEscaped appendString:urlStr];
        [inputEscaped appendString:@"\">"];
        [inputEscaped appendString:escape?escape_input(urlStr):urlStr];
        [inputEscaped appendString:@"</a>"];
        
        input = [input substringFromIndex:url.location + url.length];
        url = [input rangeOfString:regex options:NSRegularExpressionSearch];
    }
    [inputEscaped appendString:escape?escape_input(input):input];
    
    return inputEscaped;
}

@interface ConversationWindowController ()

@property (strong) IBOutlet NSSplitView *splitview;
@property (strong) IBOutlet NSTextView *conversationTextView;
@property (strong) IBOutlet NSTextView *messageInput;
@property (strong) IBOutlet NSComboButton *secureButton;
@property (strong) IBOutlet NSTextField *statusLabel;

@property BOOL fontInitialized;

@end

@implementation ConversationWindowController

- (id)initConversation:(NSString*)xid alias:(NSString*)alias xmpp:(Xmpp*)xmpp {
    self = [self initWithWindowNibName:@"ConversationWindowController"];
    _xmpp = xmpp;
    _xid = [xid copy];
    _alias = alias != nil ? [alias copy] : [_xid copy];

    _online = false;
    _unread = 0;
    _composing = false;
    _selectSingleSession = true;
    
    _fontInitialized = NO;
    
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    _tpl = app.settingsController.templateSettings;
    
    XmppSession *sn = XmppGetSession(_xmpp, [_xid UTF8String]);
    _conversation = sn->conversation;
    
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    
    [_splitview setPosition:320 ofDividerAtIndex:0];
    
    [_messageInput setDelegate:self];
    _messageInput.font = app.settingsController.InputFont;
    _messageInput.automaticDashSubstitutionEnabled = app.settingsController.TextDefaultSubDash;
    _messageInput.automaticQuoteSubstitutionEnabled = app.settingsController.TextDefaultSubQuote;
    
    _conversationTextView.font = app.settingsController.ChatFont;
    
    [self updateStatus];
    
    if(_conversation->nsessions > 1) {
        [self addStringToLog:@"xmpp: multiple sessions available\n"];
    }
}

- (void)updateStatus {
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    Presence *status = [app xidStatus:_xid];
    _online = status == nil || [status.statusMap count] == 0 ? false : true;
    PresenceStatus *presenceStatus = [status getRelevantPresenceStatus];
    
    NSString *title = _alias;
    if(status != nil && _online) {
        _statusLabel.stringValue = [presenceStatus presenceShowIconUIString:_tpl];
        if(presenceStatus.status != nil) {
            NSString *showMsg = [presenceStatus presenceShowUIString:_tpl];
            title = [[NSString alloc] initWithFormat:@"%@%@ (%@)", showMsg, _alias, presenceStatus.status];
        }
    } else {
        _statusLabel.stringValue = _tpl.xmppPresenceIconOffline;
    }
    [self.window setTitle:title];
    
    // create menu items for all available contacts
    NSMenu *comboMenu = [[NSMenu alloc] initWithTitle:@"Conversations"];
    for(int i=0;i<_conversation->nsessions;i++) {
        char *resource = _conversation->sessions[i]->resource;
        NSString *resStr = resource ? [[NSString alloc] initWithUTF8String:resource] : @"";
        
        // get the presence status message for the resource
        NSString *resShow = @"";
        NSString *resStatus = nil;
        if(status != nil) {
            PresenceStatus *resPresence = [status presenceStatus:resStr];
            if(resPresence != nil) {
                resStatus = resPresence.status;
                resShow = [resPresence presenceShowUIString:_tpl];
            }
        }
        
        NSString *itemText;
        if(resStatus == nil) {
            itemText =[NSString stringWithFormat:@"%@%@%@", resShow, _xid, resStr];
        } else {
            itemText =[NSString stringWithFormat:@"%@%@%@ (%@)", resShow, _xid, resStr, resStatus];
        }
        
        NSMenuItem *item = [[NSMenuItem alloc]initWithTitle:itemText action:@selector(selectConversation:) keyEquivalent:@""];
        item.target = self;
        if(_conversation->sessions[i]->enabled) {
            item.state = NSControlStateValueOn;
        }
        [comboMenu addItem:item];
    }
    if(_conversation->nsessions == 0) {
        NSMenuItem *item = [[NSMenuItem alloc]initWithTitle:_xid action:@selector(xidConversation:) keyEquivalent:@""];
        item.target = self;
        [comboMenu addItem:item];
    } else {
        _selectXidSession = NO;
    }
    
    [comboMenu addItem:[NSMenuItem separatorItem]];
    
    _singleSessionMenuItem = [[NSMenuItem alloc]initWithTitle:@"Select Single Session" action:@selector(singleSession:) keyEquivalent:@""];
    _singleSessionMenuItem.target = self;
    [comboMenu addItem:_singleSessionMenuItem];
    
    _multiSessionMenuItem = [[NSMenuItem alloc]initWithTitle:@"Select Multiple Sessions" action:@selector(multiSession:) keyEquivalent:@""];
    _multiSessionMenuItem.target = self;
    [comboMenu addItem:_multiSessionMenuItem];
    
    if(_selectSingleSession) {
        _singleSessionMenuItem.state = NSControlStateValueOn;
    } else {
        _multiSessionMenuItem.state = NSControlStateValueOn;
    }
 
    _secureButton.menu = comboMenu;
}

- (BOOL)selectConversation:(NSMenuItem*)sender {
    if(sender.state == NSControlStateValueOn && !_selectSingleSession) {
        sender.state = NSControlStateValueOff;
    } else {
        sender.state = NSControlStateValueOn;
    }
    bool enabled = sender.state;
    
    for(int i=0;i<_conversation->nsessions;i++) {
        NSString *itemText = [NSString stringWithFormat:@"%@%s", _xid, _conversation->sessions[i]->resource];
        if([itemText isEqualTo:sender.title]) {
            _conversation->sessions[i]->enabled = enabled;
            _conversation->sessions[i]->manually_selected = enabled;
            if(_secure && _conversation->sessions[i]->enabled && !_conversation->sessions[i]->otr) {
                // new session selected, that doesn't has an otr session
                // automatically create a new otr session
                XmppStartOtr(_xmpp, [itemText UTF8String]);
            }
        } else if(_selectSingleSession) {
            NSMenuItem *item = [sender.menu itemAtIndex:i];
            item.state = NSControlStateValueOff;
            _conversation->sessions[i]->enabled = NO;
            _conversation->sessions[i]->manually_selected = NO;
        }
    }
    
    return YES;
}

- (BOOL)xidConversation:(NSMenuItem*)sender {
    if(sender.state == NSControlStateValueOn) {
        sender.state = NSControlStateValueOff;
        _selectXidSession = NO;
    } else {
        sender.state = NSControlStateValueOn;
        _selectXidSession = YES;
    }
    return YES;
}

- (BOOL)singleSession:(NSMenuItem*)sender {
    _singleSessionMenuItem.state = NSControlStateValueOn;
    _multiSessionMenuItem.state = NSControlStateValueOff;
    _selectSingleSession = YES;
    return YES;
}
- (BOOL)multiSession:(NSMenuItem*)sender {
    _singleSessionMenuItem.state = NSControlStateValueOff;
    _multiSessionMenuItem.state = NSControlStateValueOn;
    _selectSingleSession = NO;
    return YES;
}

- (void)setSecure:(Boolean)secure resource:(nullable NSString*)resource {
    _secure = secure;
    NSString *msg =  [[NSString alloc]initWithFormat:@"%@\n", secure ? _tpl.otrGoneSecure : _tpl.otrGoneInsecure ];
    
    [self addStringToLog:msg];
    
    _secureButton.title = secure ? @"secure" : @"insecure";
    
    if(secure) {
        // enabling otr will make this session permanently enabled
        // another otr connection should't disable the otr session
        XmppSession *sn = XmppGetSession(_xmpp, resource.UTF8String);
        if(sn) {
            sn->manually_selected = true;
        }
    }
    
    size_t nsessions = _conversation->nsessions;
    if(secure && resource != nil && nsessions > 1) {
        const char *res = resource.UTF8String;
        bool updateSessions = false;
        for(size_t i=0;i<nsessions;i++) {
            char *snres = _conversation->sessions[i]->resource;
            if(snres) {
                if(_conversation->sessions[i]->enabled && strcmp(res, snres) != 0) {
                    _conversation->sessions[i]->enabled = false;
                    NSString *msg = [NSString stringWithFormat:@"unsecure session disabled: %s", snres];
                    [self addStringToLog:msg];
                    updateSessions = true;
                }
            }
        }
        
        if(updateSessions) {
            [self updateStatus];
        }
    }
}

- (void)clearChatStateMsg {
    if(_chatstateMsg == nil) {
        return;
    }
    NSTextStorage *textStorage = _conversationTextView.textStorage;
    NSUInteger textLen = [textStorage length];
    NSRange range0 = { textLen - _chatstateMsg.length, _chatstateMsg.length };
    [textStorage deleteCharactersInRange:range0];
}

- (void)chatState:(enum XmppChatstate)state {
    [self clearChatStateMsg];
    NSString *msg;
    switch(state) {
        case XMPP_CHATSTATE_ACTIVE: {
            msg = @"";
            break;
        }
        case XMPP_CHATSTATE_COMPOSING: {
            msg = [[NSString alloc]initWithFormat:@"%@\n", _tpl.chatStateComposing ];
            break;
        }
        case XMPP_CHATSTATE_PAUSED: {
            msg = [[NSString alloc]initWithFormat:@"%@\n", _tpl.chatStatePaused ];
            break;
        }
        case XMPP_CHATSTATE_INACTIVE: {
            msg = [[NSString alloc]initWithFormat:@"%@\n", _tpl.chatStateInactive ];
            break;
        }
        case XMPP_CHATSTATE_GONE: {
            msg = [[NSString alloc]initWithFormat:@"%@\n", _tpl.chatStateGone ];
            break;
        }
        default: {
            msg = @"";
            break;
        }
    }
    
    NSString *html = [NSString stringWithFormat:@"<span style=\"color: %@\">%@</span><br/>", @"darkgrey", msg];
    NSData* data = [html dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *options = @{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                              NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)};
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithHTML:data
                                                                          options:options
                                                               documentAttributes:nil];
    NSMutableAttributedString *mutableAttributedString = [attributedText mutableCopy];
    NSRange range = NSMakeRange(0, [mutableAttributedString length]);
    NSFont *newFont = [NSFont systemFontOfSize:10];
    [mutableAttributedString addAttribute:NSFontAttributeName value:newFont range:range];
    _chatstateMsg = mutableAttributedString;
    
    NSScrollView *scrollview = [_conversationTextView enclosingScrollView];
    CGFloat scrollProp = scrollview.verticalScroller.knobProportion;
    double scrollPos = scrollview.verticalScroller.doubleValue;
    bool scrollToEnd = scrollProp == 0 || scrollPos + 0.0001 > 1 ? true : false;
    
    NSTextStorage *textStorage = _conversationTextView.textStorage;
    [textStorage appendAttributedString:mutableAttributedString];
    
    if(scrollToEnd) {
        [_conversationTextView scrollToEndOfDocument:nil];
    }
}

- (void)otrError:(uint64_t)error from:(NSString*)from {
    NSString *msg = @"";
    switch(error) {
        case OTRL_MSGEVENT_ENCRYPTION_REQUIRED: {
            msg = @"encryption required";
            break;
        }
        case OTRL_MSGEVENT_ENCRYPTION_ERROR: {
            msg = @"encryption error";
            break;
        }
        case OTRL_MSGEVENT_CONNECTION_ENDED: {
            msg = @"connection ended";
            break;
        }
        case OTRL_MSGEVENT_SETUP_ERROR: {
            msg = @"setup error";
            break;
        }
        case OTRL_MSGEVENT_MSG_REFLECTED: {
            msg = @"message reflected";
            break;
        }
        case OTRL_MSGEVENT_MSG_RESENT: {
            msg = @"message resent";
            break;
        }
        case OTRL_MSGEVENT_RCVDMSG_NOT_IN_PRIVATE: {
            msg = @"received message not in private";
            break;
        }
        case OTRL_MSGEVENT_RCVDMSG_UNREADABLE: {
            msg = @"received message unreadable";
            break;
        }
        case OTRL_MSGEVENT_RCVDMSG_MALFORMED: {
            msg = @"received message malformed";
            break;
        }
        case OTRL_MSGEVENT_LOG_HEARTBEAT_RCVD: {
            return; // no error
        }
        case OTRL_MSGEVENT_LOG_HEARTBEAT_SENT: {
            return; // no error
        }
        case OTRL_MSGEVENT_RCVDMSG_GENERAL_ERR: {
            msg = @"received message general err";
            break;
        }
        case OTRL_MSGEVENT_RCVDMSG_UNENCRYPTED: {
            msg = @"received message unencrypted";
            break;
        }
        case OTRL_MSGEVENT_RCVDMSG_UNRECOGNIZED: {
            msg = @"received message unrecognized";
            break;
        }
        case OTRL_MSGEVENT_RCVDMSG_FOR_OTHER_INSTANCE: {
            msg = @"received message for other instance";
            break;
        }
    }
    
    NSString *otrmsg = [NSString stringWithFormat:@"otr message: from: %@: %@\n", from, msg];
    
    [self addStringToLog:otrmsg];
}

- (void)newFingerprint:(NSString*)fingerprint from:(NSString*)from {
    NSString *msg = [NSString stringWithFormat:@"otr: new fingerprint: %@ from %@\n", fingerprint, from];
    [self addStringToLog:msg];
}

- (void)addStringToLog:(NSString*)str {
    if(str == nil) {
        return;
    }
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:str];
    [self addAttributedStringToLog:attributedText];
}

- (void)addAttributedStringToLog:(NSAttributedString*)str {
    if(str == nil) {
        return;
    }
    
    NSScrollView *scrollview = [_conversationTextView enclosingScrollView];
    CGFloat scrollProp = scrollview.verticalScroller.knobProportion;
    double scrollPos = scrollview.verticalScroller.doubleValue;
    bool scrollToEnd = scrollProp == 0 || scrollPos + 0.0001 > 1 ? true : false;
    
    NSTextStorage *textStorage = _conversationTextView.textStorage;
    NSUInteger chatStateLen = _chatstateMsg == nil ? 0 : _chatstateMsg.length;
    [textStorage insertAttributedString:str atIndex:textStorage.length - chatStateLen];
    
    if(scrollToEnd) {
        [_conversationTextView scrollToEndOfDocument:nil];
    }
}

- (void)updateFonts:(NSFont*)chatFont inputFont:(NSFont*)inputFont {
    _conversationTextView.font = chatFont;
    _messageInput.font = inputFont;
}


- (void)addLog:(NSString*)message incoming:(Boolean)incoming secure:(Boolean)secure {
    NSScrollView *scrollview = [_conversationTextView enclosingScrollView];
    CGFloat scrollProp = scrollview.verticalScroller.knobProportion;
    double scrollPos = scrollview.verticalScroller.doubleValue;
    bool scrollToEnd = scrollProp == 0 || scrollPos + 0.0001 > 1 ? true : false;
    
    
    NSString *name;
    if(incoming) {
        name = _alias;
    } else {
        char *my_alias = _xmpp->settings.alias ? _xmpp->settings.alias : _xmpp->settings.jid;
        name = [[NSString alloc]initWithUTF8String: my_alias];
    }
    
    NSString *color = incoming ? @"red" : @"blue";
    
    NSString *htmlFormat = nil;
    if(incoming) {
        htmlFormat = _tpl.htmlMsgInFormat;
    } else {
        htmlFormat = _tpl.htmlMsgOutFormat;
    }
    
    NSString *entry;
    if(htmlFormat == nil) {
        // no html format defined, use plain text msg prefix settings
        NSString *msgPrefix = [_tpl msgPrefixFormatWithFormat:incoming ? _tpl.msgInPrefixFormat : _tpl.msgOutPrefixFormat xid:_xid alias:name secure:secure message:@""];
        entry = [NSString stringWithFormat:@"<pre style=\"font-family: -apple-system\"><span style=\"color: %@\">%@</span>%@</pre>", color, msgPrefix, message];
    } else {
        entry = [_tpl msgPrefixFormatWithFormat:htmlFormat xid:_xid alias:name secure:secure message:message];
    }
    
    NSTextStorage *textStorage = _conversationTextView.textStorage;
    
    NSData* data = [entry dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *options = @{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                              NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)};
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithHTML:data
                                                                          options:options
                                                               documentAttributes:nil];
    
    NSUInteger chatStateLen = _chatstateMsg == nil ? 0 : _chatstateMsg.length;
    [textStorage insertAttributedString:attributedText atIndex:textStorage.length - chatStateLen];
    
    if(scrollToEnd) {
        [_conversationTextView scrollToEndOfDocument:nil];
    }
    
    // workaround: for some reason this is required
    if(!_fontInitialized) {
        AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
        _conversationTextView.font = app.settingsController.ChatFont;
        _fontInitialized = YES;
    }
}

- (void)sendMessage:(Boolean)force {
    // check if a session is enabled
    BOOL sessionEnabled = FALSE;
    for(int i=0;i<_conversation->nsessions;i++) {
        XmppSession *sn = _conversation->sessions[i];
        if(sn->enabled) {
            sessionEnabled = TRUE;
        }
    }
    if(!sessionEnabled && !_selectXidSession) {
        // inform the user that no message was sent
        [self addStringToLog:@"xmpp: no active sessions: no message sent\n"];
        return;
    }
    
    // unencrypted message warning
    if(!_secure && !force) {
        AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
        int unencrypted = app.settingsController.UnencryptedMessages;
        // unencrypted message values:
        // 0: warn
        // 1: allow
        // 2: disabled
        if(unencrypted == 0) {
            // warn
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Unencrypted Message"];
            [alert setInformativeText:@"Do you want to send an unencrypted message?"];
            [alert addButtonWithTitle:@"Send Message"];
            [alert addButtonWithTitle:@"Cancel"];

            [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
                if (returnCode == NSAlertFirstButtonReturn) {
                    [self sendMessage:YES];
                }
            }];
            return;
        } else if(unencrypted == 2) {
            // unencrypted messages are not allowed
            [self addStringToLog:@"xmpp: unencrypted communication is disabled: no message sent\n"];
            return;
        }
    }
    
    // apply outgoing message filters
    char *msg = strdup([_messageInput.string UTF8String]);
    apply_all_rules(&msg);
    NSString *input = [[NSString alloc]initWithUTF8String:msg];
    free(msg);
    
    NSString *inputEscaped = convert_urls_to_links(input, true);
    
    // if otr is on, we have to give the Xmpp module an escaped string
    // without otr, libstrophe will automatically escape the text
    // maybe the escaping should be moved to xmpp.c, however we also need
    // an escaped string for the message log
    // it is also currently impossible to send html when encryption is off
    const char *message = _secure ? [inputEscaped UTF8String] : [convert_urls_to_links(input, false) UTF8String];
    
    BOOL msgSent = FALSE;
    for(int i=0;i<_conversation->nsessions;i++) {
        XmppSession *sn = _conversation->sessions[i];
        if(sn->enabled) {
            NSString *to = [NSString stringWithFormat:@"%@%s", _xid, sn->resource];
            XmppMessage(_xmpp, [to UTF8String], message, _secure);
            msgSent = TRUE;
        }
    }
    if(_selectXidSession && !msgSent) {
        XmppMessage(_xmpp, [_xid UTF8String], message, _secure);
        msgSent = TRUE;
    }
    
    [self addLog:inputEscaped incoming:FALSE secure:_secure];
    _composing = FALSE;
    [_messageInput setString:@""];
}

- (void)sendState:(enum XmppChatstate)state {
    for(int i=0;i<_conversation->nsessions;i++) {
        XmppSession *sn = _conversation->sessions[i];
        if(sn->enabled) {
            NSString *to = [NSString stringWithFormat:@"%@%s", _xid, sn->resource];
            XmppStateMessage(_xmpp, [to UTF8String], state);
        }
    }
}

- (void)addReceivedMessage:(NSString*)msg resource:(NSString*)res secure:(BOOL)secure {
    [self addLog:msg incoming:TRUE secure:secure];
    
    if(![self.window isKeyWindow]) {
        _unread++;
        AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
        [app addUnread:1];
        
        if([app.outlineViewController updateContact:_xid updateStatus:false presence:nil unread:_unread]) {
           [app.contactList reloadData];
        }
    }
}

- (IBAction) secureAction:(id)sender {
    if(_secure) {
        if(_online) {
            for(int i=0;i<_conversation->nsessions;i++) {
                XmppSession *sn = _conversation->sessions[i];
                if(sn->otr) {
                    NSString *to = [NSString stringWithFormat:@"%@%s", _xid, sn->resource];
                    XmppStopOtr(_xmpp, [to UTF8String]);
                    [self setSecure:false resource:nil];
                }
            }
        } else {
            _secure = false;
            _secureButton.title = @"insecure";
            
            NSString *msg = _tpl.otrDisabled;
            
            [self addStringToLog:msg];
        }
    } else {
        if(_online) {
            for(int i=0;i<_conversation->nsessions;i++) {
                XmppSession *sn = _conversation->sessions[i];
                if(sn->enabled) {
                    NSString *to = [NSString stringWithFormat:@"%@%s", _xid, sn->resource];
                    XmppStartOtr(_xmpp, [to UTF8String]);
                }
            }
        }
    }
}


#pragma mark - NSTextViewDelegate Methods

-(void)textDidChange:(NSNotification *)notification {
    NSTextStorage *textStorage = _messageInput.textStorage;
    NSUInteger len = textStorage.length;
    if(_composing) {
        if(len == 0) {
            [self sendState:XMPP_CHATSTATE_ACTIVE];
            _composing = FALSE;
        }
    } else {
        if(len != 0) {
            [self sendState:XMPP_CHATSTATE_COMPOSING];
            _composing = TRUE;
        }
    }
}

#pragma mark - NSWindowDelegate Methods

- (void)windowWillClose:(NSNotification *)notification {
    
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if(commandSelector == @selector(insertNewline:)) {
        NSEvent *ev = [NSApp currentEvent];
        if(ev.type == NSEventTypeKeyDown) {
            [self sendMessage:NO];
            return YES;
        }
    }
    return NO;
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [app addUnread:-_unread];
    _unread = 0;
    
    if([app.outlineViewController updateContact:_xid updateStatus:false presence:nil unread:0]) {
        [app.contactList reloadData];
    }
    
    [self.window makeFirstResponder:_messageInput];
}

- (IBAction)saveDocument:(id)sender {
    if(!_historyFile) {
        [self saveDocumentAs:sender];
        return;
    }
    
    [self clearChatStateMsg];
    
    NSAttributedString *attributedString = _conversationTextView.textStorage;
    
    NSDictionary *documentAttributes = @{
        NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
        NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)
    };
    
    NSError *error;
    NSData *htmlData = [attributedString dataFromRange:NSMakeRange(0, attributedString.length)
                                  documentAttributes:documentAttributes
                                               error:&error];
    if(htmlData == nil) {
        NSString *errormsg = [[NSString alloc] initWithFormat:@"Cannot save the conversation: %@", error.localizedDescription];
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Error"];
        [alert setInformativeText:errormsg];
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
    } else if (![htmlData writeToURL:_historyFile atomically:YES]) {
        NSString *errormsg = [[NSString alloc] initWithFormat:@"Cannot save the conversation to the file: %@", _historyFile.absoluteString];
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Error"];
        [alert setInformativeText:errormsg];
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:self.window completionHandler:nil];
    }
    
    [self addStringToLog:@"\n"]; // fixes missing newline after clearChatStateMsg
}

- (IBAction)saveDocumentAs:(id)sender {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    
    // the default filename is <date>_<xid>.html
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    NSString *dateStr = [dateFormatter stringFromDate:currentDate];
    
    NSString *fileName = [[NSString alloc] initWithFormat:@"%@_%@.html", dateStr, _xid];
    [savePanel setNameFieldStringValue:fileName];
    
    if ([savePanel runModal] == NSModalResponseOK) {
        _historyFile = [savePanel URL];
        
        [self saveDocument:sender];
    }
}

- (IBAction)add:(id)sender {
    printf("Conversation add\n");
}

@end

