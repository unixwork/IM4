//
//  ConversationWindowController.m
//  IM4
//
//  Created by Olaf Wintermann on 13.08.23.
//

#import "ConversationWindowController.h"

#include "xmpp.h"

@interface ConversationWindowController ()

@property (strong) IBOutlet NSSplitView *splitview;
@property (strong) IBOutlet NSTextView *conversationTextView;
@property (strong) IBOutlet NSTextView *messageInput;

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
    
    printf("window did load\n");
}

- (void)addLog:(NSString*)message incoming:(Boolean)incoming {
    NSString *name = incoming ? @"<" : @">";
    NSString *entry = [NSString stringWithFormat:@"%@ %@\n", name, message];
    
    NSTextStorage *textStorage = self.conversationTextView.textStorage;
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:entry];
    [textStorage appendAttributedString:attributedText];
    [self.conversationTextView scrollToEndOfDocument:nil];
}

- (void)sendMessage {
    NSString *input = _messageInput.string;
    const char *message = [input UTF8String];
    
    XmppMessage(_xmpp, [_xid UTF8String], message);
    
    [self addLog:input incoming:FALSE];
    [_messageInput setString:@""];
}

- (void)addReceivedMessage:(NSString*)msg {
    [self addLog:msg incoming:TRUE];
}

- (IBAction) testAction:(id)sender {
    printf("testAction\n");
}

#pragma mark - NSWindowDelegate Methods

- (void)windowWillClose:(NSNotification *)notification {
    //printf("window close\n");
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    printf("> text command\n");
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
