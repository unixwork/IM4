//
//  ConversationWindowController.m
//  IM4
//
//  Created by Olaf Wintermann on 13.08.23.
//

#import "ConversationWindowController.h"
#import "AppDelegate.h"

#include "xmpp.h"

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
    _statusLabel.stringValue = status == nil || [status count] == 0 ? @"🔴" : @"🟢";
    
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
    // TODO: add message to log
    _secureButton.title = secure ? @"secure" : @"insecure";
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
    
    NSString *entry = [NSString stringWithFormat:@"%@(%@) %@: %@<br/>", incomingStr, time, name, message];
    
    NSTextStorage *textStorage = self.conversationTextView.textStorage;
    //NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:entry];
    
    NSData* data = [entry dataUsingEncoding:NSUTF8StringEncoding];
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithHTML:data
                                            baseURL:nil
                                 documentAttributes:nil];
    NSMutableAttributedString *mutableAttributedString = [attributedText mutableCopy];
    NSRange range = NSMakeRange(0, [mutableAttributedString length]);
    NSFont *newFont = [NSFont systemFontOfSize:12];
    [mutableAttributedString addAttribute:NSFontAttributeName value:newFont range:range];
    
    [textStorage appendAttributedString:mutableAttributedString];
    [self.conversationTextView scrollToEndOfDocument:nil];
}

- (void)sendMessage {
    NSString *input = _messageInput.string;
    const char *message = [input UTF8String];
    
    for(NSString *session in _activeSessions) {
        NSString *to = [NSString stringWithFormat:@"%@%@", _xid, session];
        XmppMessage(_xmpp, [to UTF8String], message, _secure);
    }
    
    if(_activeSessions.count > 0) {
        [self addLog:input incoming:FALSE];
    } else {
        NSTextStorage *textStorage = self.conversationTextView.textStorage;
        NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:@"no active sessions"];
        [textStorage appendAttributedString:attributedText];
        [self.conversationTextView scrollToEndOfDocument:nil];
    }
    [_messageInput setString:@""];
}

- (void)addReceivedMessage:(NSString*)msg resource:(NSString*)res {
    [self addLog:msg incoming:TRUE];
}

- (IBAction) secureAction:(id)sender {
    printf("secure\n");
    if(_secure) {
        for(NSString *session in _activeSessions) {
            NSString *to = [NSString stringWithFormat:@"%@%@", _xid, session];
            XmppStopOtr(_xmpp, [to UTF8String]);
            [self setSecure:false session:session];
        }
    } else {
        for(NSString *session in _activeSessions) {
            NSString *to = [NSString stringWithFormat:@"%@%@", _xid, session];
            XmppStartOtr(_xmpp, [to UTF8String]);
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

@end
