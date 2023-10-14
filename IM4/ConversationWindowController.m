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

- (id)initConversation:(NSString*)xid xmpp:(Xmpp*)xmpp {
    self = [self initWithWindowNibName:@"ConversationWindowController"];
    _xmpp = xmpp;
    _xid = [xid copy];
    
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    
    [_splitview setPosition:320 ofDividerAtIndex:0];
    
    [_messageInput setDelegate:self];
    
    [self.window setTitle:_xid];
    
    [self updateStatus];
}

- (void)updateStatus {
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [_statusLabel setStringValue:[app xidStatusIcon:_xid]];
}

- (void)setSecure:(Boolean)secure {
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
        name = [app xidAlias:_xid];
    } else {
        char *my_alias = _xmpp->settings.alias;
        if(my_alias) {
            name = [[NSString alloc]initWithUTF8String: my_alias];
        } else {
            name = _xid;
        }
    }
    
    NSString *incomingStr = incoming ? @"< " : @"> ";
    
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss"];
    NSString *time = [dateFormatter stringFromDate:currentDate];
    
    NSString *entry = [NSString stringWithFormat:@"%@(%@) %@: %@\n", incomingStr, time, name, message];
    
    NSTextStorage *textStorage = self.conversationTextView.textStorage;
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:entry];
    [textStorage appendAttributedString:attributedText];
    [self.conversationTextView scrollToEndOfDocument:nil];
}

- (void)sendMessage {
    NSString *input = _messageInput.string;
    const char *message = [input UTF8String];
    
    XmppMessage(_xmpp, [_xid UTF8String], message, _secure);
    
    [self addLog:input incoming:FALSE];
    [_messageInput setString:@""];
}

- (void)addReceivedMessage:(NSString*)msg {
    [self addLog:msg incoming:TRUE];
}

- (IBAction) secureAction:(id)sender {
    printf("secure\n");
    XmppStartOtr(_xmpp, [_xid UTF8String]);
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
