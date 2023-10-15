//
//  AppDelegate.h
//  IM4
//
//  Created by Olaf Wintermann on 11.08.23.
//

#import <Cocoa/Cocoa.h>
#import "OutlineViewController.h"
#import "SettingsController.h"

#import "xmpp.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readonly) Xmpp *xmpp;

@property (readonly) NSMutableDictionary *conversations;

@property (readonly) NSMutableDictionary *presence;

@property (strong) SettingsController *settingsController;


- (NSString*) appConfigFilePath: (NSString*)fileName;

- (void) setStatus:(int)status xmpp:(Xmpp*)xmpp;

- (NSString*) xidStatusIcon:(NSString*)xid;

- (NSDictionary*) xidStatus:(NSString*)xid;

- (NSString*) xidAlias:(NSString*)xid;

- (void) handleXmppMessage:(const char*)msg_body from:(const char*)from xmpp:(Xmpp*)xmpp;

- (void) handlePresence:(const char*)from status:(const char*)status xmpp:(Xmpp*)xmpp;

- (void) handleSecureStatus:(Boolean)status from:(const char*)from xmpp:(Xmpp*)xmpp;

- (void) refreshContactList;

- (void) openConversation:(Contact*)contact;

- (void) updateConversationAlias:(NSString*)xid newAlias:(NSString*)alias;

- (void) startXmpp;


- (IBAction) menuPreferences:(id)sender;

@end

