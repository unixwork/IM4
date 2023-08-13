//
//  ConversationWindowController.h
//  IM4
//
//  Created by Olaf Wintermann on 13.08.23.
//

#import <Cocoa/Cocoa.h>

#include "xmpp.h"

NS_ASSUME_NONNULL_BEGIN

@interface ConversationWindowController : NSWindowController<NSWindowDelegate, NSTextViewDelegate>

@property (readonly) Xmpp *xmpp;
@property (copy) NSString* xid;

- (id)initConversation:(NSString*)xid xmpp:(Xmpp*)xmpp;

- (void)addLog:(NSString*)message incoming:(Boolean)incoming;

- (void)sendMessage;

- (void)addReceivedMessage:(NSString*)msg;

- (IBAction) testAction:(id)sender;

@end

NS_ASSUME_NONNULL_END