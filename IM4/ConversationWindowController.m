//
//  ConversationWindowController.m
//  IM4
//
//  Created by Olaf Wintermann on 13.08.23.
//

#import "ConversationWindowController.h"

@interface ConversationWindowController ()

@end

@implementation ConversationWindowController

- (id)initConversation:(NSString*)xid {
    self = [self initWithWindowNibName:@"ConversationWindowController"];
    _xid = [xid copy];
    
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    printf("window did load\n");
}

- (IBAction) testAction:(id)sender {
    printf("testAction\n");
}

#pragma mark - NSWindowDelegate Methods

- (void)windowWillClose:(NSNotification *)notification {
    //printf("window close\n");
}

@end
