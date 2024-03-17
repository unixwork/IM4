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

#import <Cocoa/Cocoa.h>
#import "OutlineViewController.h"
#import "SettingsController.h"
#import "LogWindowController.h"
#import "ConversationWindowController.h"

#import "xmpp.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readonly) Xmpp *xmpp;

@property (readonly) NSMutableDictionary *conversations;

@property (readonly) NSMutableDictionary *presence;

@property (strong) IBOutlet NSOutlineView *contactList;
@property (strong) IBOutlet OutlineViewController *outlineViewController;

@property (strong) SettingsController *settingsController;
@property (strong) LogWindowController *logWindowController;

@property (strong) IBOutlet NSPopUpButton *statusButton;
@property (strong) IBOutlet NSMenuItem *onlineItem;
@property (strong) IBOutlet NSMenuItem *offlineItem;

@property (strong) IBOutlet NSTextField *loginDialogXidLabel;
@property (strong) IBOutlet NSTextField *loginDialogPassword;

@property (strong) IBOutlet NSTextField *openConversationXidTextField;
@property (strong) IBOutlet NSTextField *openConversationErrorField;

@property int unread;


- (void) setStatus:(int)status xmpp:(Xmpp*)xmpp;

- (NSString*) xidStatusIcon:(NSString*)xid;

- (NSDictionary*) xidStatus:(NSString*)xid;

- (NSString*) xidAlias:(NSString*)xid;

- (ConversationWindowController*) conversationController:(XmppSession*)session;

- (void) addUnread:(int)num;

- (void) handleXmppMessage:(const char*)msg_body from:(const char*)from session:(XmppSession*)session secure:(BOOL)secure xmpp:(Xmpp*)xmpp;

- (void) handlePresence:(const char*)from status:(const char*)status xmpp:(Xmpp*)xmpp;

- (void) handleChatstate:(const char*)from state:(enum XmppChatstate)state session:(XmppSession*)session;

- (void) handleSecureStatus:(Boolean)status from:(const char*)from session:(XmppSession*)session xmpp:(Xmpp*)xmpp;

- (void) handleNewFingerprint:(unsigned char*)fingerprint length:(size_t)len from:(const char*)from session:(XmppSession*)session xmpp:(Xmpp*)xmpp;

- (void) handleOtrError:(uint64_t)error from:(const char*)from session:(XmppSession*)session xmpp:(Xmpp*)xmpp;

- (void) refreshContactList;

- (void) openConversation:(Contact*)contact;

- (void) updateConversationAlias:(NSString*)xid newAlias:(NSString*)alias;

- (void) startXmpp;

- (IBAction) menuPreferences:(id)sender;
- (IBAction) menuDebugLog:(id)sender;
- (IBAction) menuContactList:(id)sender;

- (IBAction) statusSelected:(id)sender;

- (IBAction) loginCancel:(id)sender;
- (IBAction) loginOK:(id)sender;

- (IBAction) openConversationCancel:(id)sender;
- (IBAction) openConversationOK:(id)sender;

- (IBAction)newDocument:(id)sender;

@end

enum StatusTag {
    IM4_OFFLINE = 0,
    IM4_ONLINE
};
