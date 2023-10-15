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
@property (readonly) Boolean secure;
@property (copy) NSString* xid;
@property (copy) NSString* alias;
@property (readonly) NSMutableDictionary* activeSessions;

- (id)initConversation:(NSString*)xid alias:(NSString*)alias xmpp:(Xmpp*)xmpp;

- (void)updateStatus;

- (BOOL)selectConversation:(NSMenuItem*)sender;

- (void)addLog:(NSString*)message incoming:(Boolean)incoming;

- (void)sendMessage;

- (void)addReceivedMessage:(NSString*)msg resource:(NSString*)res;

- (void)setSecure:(Boolean)secure session:(NSString*)session;

- (IBAction) testAction:(id)sender;

- (IBAction) secureAction:(id)sender;

@end

NS_ASSUME_NONNULL_END
