//
//  ConversationWindowController.m
//  IM4
//
//  Created by Olaf Wintermann on 13.08.23.
//

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
    
    return [[NSString alloc] initWithString:inputEscaped];
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
    _activeSessions = [[NSMutableDictionary alloc]init];
    
    _online = false;
    _unread = 0;
    
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    
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
    
    NSMutableDictionary *sessions = [[NSMutableDictionary alloc]init];
    
    NSMenu *comboMenu = [[NSMenu alloc] initWithTitle:@"Conversations"];
    NSMenuItem *lastItem = nil;
    for(NSString *res in status) {
        NSString *itemText = [NSString stringWithFormat:@"%@%@", _xid, res];
        NSMenuItem *item = [[NSMenuItem alloc]initWithTitle:itemText action:@selector(selectConversation:) keyEquivalent:@""];
        item.target = self;
        if(status.count == 1) {
            item.state = NSControlStateValueOn;
        } else {
            
        }
        [comboMenu addItem:item];
        
        if(item.state == NSControlStateValueOn) {
            [sessions setValue:@"1" forKey:res];
        }
    }
    [comboMenu addItem:[NSMenuItem separatorItem]];
    
    
    _secureButton.menu = comboMenu;
    _activeSessions = sessions;
}

- (BOOL)selectConversation:(NSMenuItem*)sender {
    // TODO
    return true;
}

- (void)setSecure:(Boolean)secure session:(NSString*)session {
    _secure = secure;
    NSString *msg = secure ? @"otr: gone secure\n" : @"otr: gone insecure\n";
    
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:msg];
    NSTextStorage *textStorage = _conversationTextView.textStorage;
    [textStorage appendAttributedString:attributedText];
    [_conversationTextView scrollToEndOfDocument:nil];
    
    _secureButton.title = secure ? @"secure" : @"insecure";
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
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:otrmsg];
    
    NSTextStorage *textStorage = _conversationTextView.textStorage;
    [textStorage appendAttributedString:attributedText];
    [_conversationTextView scrollToEndOfDocument:nil];
}

- (void)newFingerprint:(NSString*)fingerprint from:(NSString*)from {
    NSString *msg = [NSString stringWithFormat:@"otr: new fingerprint: %@ from %@\n", fingerprint, from];
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:msg];
    
    NSTextStorage *textStorage = _conversationTextView.textStorage;
    [textStorage appendAttributedString:attributedText];
    [_conversationTextView scrollToEndOfDocument:nil];
}

- (void)addLog:(NSString*)message incoming:(Boolean)incoming {
    //NSString *name = incoming ? @"<" : @">";
    //NSString *entry = [NSString stringWithFormat:@"%@ %@\n", name, message];
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    
    NSString *name;
    if(incoming) {
        name = _alias;
    } else {
        char *my_alias = _xmpp->settings.alias ? _xmpp->settings.alias : _xmpp->settings.jid;
        name = [[NSString alloc]initWithUTF8String: my_alias];
    }
    
    NSString *incomingStr = incoming ? @"< " : @"> ";
    
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss"];
    NSString *time = [dateFormatter stringFromDate:currentDate];
    NSString *color = incoming ? @"red" : @"blue";
    
    NSString *entry = [NSString stringWithFormat:@"<pre><span style=\"color: %@\">%@(%@) %@</span>: %@</pre>", color, incomingStr, time, name, message];
    
    NSTextStorage *textStorage = _conversationTextView.textStorage;
    //NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:entry];
    
    NSData* data = [entry dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *options = @{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                              NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)};
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithHTML:data
                                                                          options:options
                                                               documentAttributes:nil];
    NSMutableAttributedString *mutableAttributedString = [attributedText mutableCopy];
    NSRange range = NSMakeRange(0, [mutableAttributedString length]);
    NSFont *newFont = [NSFont systemFontOfSize:12];
    [mutableAttributedString addAttribute:NSFontAttributeName value:newFont range:range];
    
    [textStorage appendAttributedString:mutableAttributedString];
    [_conversationTextView scrollToEndOfDocument:nil];
}

- (void)sendMessage {
    NSString *input = _messageInput.string;
    NSString *inputEscaped = escape_input(input);
    
    // if otr is on, we have to give the Xmpp module an escaped string
    // without otr, libstrophe will automatically escape the text
    // maybe the escaping should be moved to xmpp.c, however we also need
    // an escaped string for the message log
    // it is also currently impossible to send html when encryption is off
    const char *message = _secure ? [inputEscaped UTF8String] : [input UTF8String];
    
    for(NSString *session in _activeSessions) {
        NSString *to = [NSString stringWithFormat:@"%@%@", _xid, session];
        XmppMessage(_xmpp, [to UTF8String], message, _secure);
    }
    
    if(_activeSessions.count > 0) {
        [self addLog:inputEscaped incoming:FALSE];
    } else {
        NSTextStorage *textStorage = _conversationTextView.textStorage;
        NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:@"no active sessions"];
        [textStorage appendAttributedString:attributedText];
        [_conversationTextView scrollToEndOfDocument:nil];
    }
    [_messageInput setString:@""];
}

- (void)addReceivedMessage:(NSString*)msg resource:(NSString*)res {
    [self addLog:msg incoming:TRUE];
    
    if(![self.window isKeyWindow]) {
        _unread++;
        AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
        [app addUnread:1];
    }
}

- (IBAction) secureAction:(id)sender {
    printf("secure\n");
    if(_secure) {
        if(_online) {
            for(NSString *session in _activeSessions) {
                NSString *to = [NSString stringWithFormat:@"%@%@", _xid, session];
                XmppStopOtr(_xmpp, [to UTF8String]);
                [self setSecure:false session:session];
            }
        } else {
            _secure = false;
            _secureButton.title = @"insecure";
            
            NSString *msg = @"otr disabled\n";
            NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:msg];
            NSTextStorage *textStorage = _conversationTextView.textStorage;
            [textStorage appendAttributedString:attributedText];
            [_conversationTextView scrollToEndOfDocument:nil];
        }
    } else {
        if(_online) {
            for(NSString *session in _activeSessions) {
                NSString *to = [NSString stringWithFormat:@"%@%@", _xid, session];
                XmppStartOtr(_xmpp, [to UTF8String]);
            }
        }
    }
    
    if(_activeSessions.count == 0) {
        // TODO: add message
    }
}

- (IBAction) testAction:(id)sender {
    printf("testAction\n");
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
}

@end

