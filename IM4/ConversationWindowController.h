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
@property (readonly) XmppConversation *conversation;
@property (readonly) Boolean secure;
@property (copy) NSString* xid;
@property (copy) NSString* alias;
@property bool online;
@property bool loading;
@property bool composing;
@property int unread;
@property NSString* chatstateMsg;
@property bool selectSingleSession;
@property (readonly) NSMenuItem *singleSessionMenuItem;
@property (readonly) NSMenuItem *multiSessionMenuItem;

- (id)initConversation:(NSString*)xid alias:(NSString*)alias xmpp:(Xmpp*)xmpp;

- (void)updateStatus;

- (BOOL)selectConversation:(NSMenuItem*)sender;
- (BOOL)singleSession:(NSMenuItem*)sender;
- (BOOL)multiSession:(NSMenuItem*)sender;

- (void)addStringToLog:(NSString*)str;

- (void)addLog:(NSString*)message incoming:(Boolean)incoming;

- (void)sendMessage;

- (void)sendState:(enum XmppChatstate) state;

- (void)addReceivedMessage:(NSString*)msg resource:(NSString*)res;

- (void)clearChatStateMsg;

- (void)chatState:(enum XmppChatstate)state;

- (void)otrError:(uint64_t)error from:(NSString*)from;

- (void)setSecure:(Boolean)secure;

- (void)newFingerprint:(NSString*)fingerprint from:(NSString*)from;

- (IBAction) testAction:(id)sender;

- (IBAction) secureAction:(id)sender;



@end

NS_ASSUME_NONNULL_END
