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
    
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    _tpl = app.settingsController.templateSettings;
    
    XmppSession *sn = XmppGetSession(_xmpp, [_xid UTF8String]);
    _conversation = sn->conversation;
    
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [_splitview setPosition:320 ofDividerAtIndex:0];
    
    [_messageInput setDelegate:self];
    
    [self.window setTitle:_alias];
    
    [self updateStatus];
}

- (void)updateStatus {
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    NSDictionary *status = [app xidStatus:_xid];
    _online = status == nil || [status count] == 0 ? false : true;
    _statusLabel.stringValue = !_online ? @"🔴" : @"🟢";
    
    // create menu items for all available contacts
    NSMenu *comboMenu = [[NSMenu alloc] initWithTitle:@"Conversations"];
    for(int i=0;i<_conversation->nsessions;i++) {
        NSString *itemText = [NSString stringWithFormat:@"%@%s", _xid, _conversation->sessions[i]->resource];
        NSMenuItem *item = [[NSMenuItem alloc]initWithTitle:itemText action:@selector(selectConversation:) keyEquivalent:@""];
        item.target = self;
        if(_conversation->sessions[i]->enabled) {
            item.state = NSControlStateValueOn;
        }
        [comboMenu addItem:item];
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
    
    for(int i=0;i<_conversation->nsessions;i++) {
        NSString *itemText = [NSString stringWithFormat:@"%@%s", _xid, _conversation->sessions[i]->resource];
        if([itemText isEqualTo:sender.title]) {
            _conversation->sessions[i]->enabled = sender.state;
            if(_secure && _conversation->sessions[i]->enabled && !_conversation->sessions[i]->otr) {
                // new session selected, that doesn't has an otr session
                // automatically create a new otr session
                XmppStartOtr(_xmpp, [itemText UTF8String]);
            }
        } else if(_selectSingleSession) {
            NSMenuItem *item = [sender.menu itemAtIndex:i];
            item.state = NSControlStateValueOff;
            _conversation->sessions[i]->enabled = NO;
        }
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

- (void)setSecure:(Boolean)secure {
    _secure = secure;
    NSString *msg =  [[NSString alloc]initWithFormat:@"%@\n", secure ? _tpl.otrGoneSecure : _tpl.otrGoneInsecure ];
    
    [self addStringToLog:msg];
    
    _secureButton.title = secure ? @"secure" : @"insecure";
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
        NSString *msgPrefix = [_tpl msgPrefixFormatWithFormat:incoming ? _tpl.msgInPrefixFormat : _tpl.msgOutPrefixFormat xid:_xid alias:name secure:secure];
        entry = [NSString stringWithFormat:@"<pre style=\"font-family: -apple-system\"><span style=\"color: %@\">%@</span>%@</pre>", color, msgPrefix, message];
    } else {
        entry = [_tpl msgPrefixFormatWithFormat:htmlFormat xid:_xid alias:name secure:secure];
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
}

- (void)sendMessage {
    NSString *input = _messageInput.string;
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
    
    if(msgSent) {
        [self addLog:inputEscaped incoming:FALSE secure:_secure];
        _composing = FALSE;
    } else {
        // inform the user that no message was sent
        [self addStringToLog:@"no active sessions: no meesage sent\n"];
    }
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
        
        if([app.outlineViewController updateContact:_xid updateStatus:false status:nil unread:_unread]) {
            [app.contactList reloadData];
        }
    }
}

- (IBAction) secureAction:(id)sender {
    printf("secure\n");
    if(_secure) {
        if(_online) {
            for(int i=0;i<_conversation->nsessions;i++) {
                XmppSession *sn = _conversation->sessions[i];
                if(sn->otr) {
                    NSString *to = [NSString stringWithFormat:@"%@%s", _xid, sn->resource];
                    XmppStopOtr(_xmpp, [to UTF8String]);
                    [self setSecure:false];
                }
            }
        } else {
            _secure = false;
            _secureButton.title = @"insecure";
            
            NSString *msg = @"otr disabled\n";
            
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

- (IBAction) testAction:(id)sender {
    printf("testAction\n");
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
    printf("window close\n");
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if(commandSelector == @selector(insertNewline:)) {
        NSEvent *ev = [NSApp currentEvent];
        if(ev.type == NSEventTypeKeyDown) {
            [self sendMessage];
            return YES;
        }
    }
    return NO;
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [app addUnread:-_unread];
    _unread = 0;
    
    if([app.outlineViewController updateContact:_xid updateStatus:false status:nil unread:0]) {
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
    // TODO: check error
    
    if (![htmlData writeToURL:_historyFile atomically:YES]) {
        // TODO: error
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

@end

