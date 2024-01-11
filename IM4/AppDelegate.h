//
//  AppDelegate.h
//  IM4
//
//  Created by Olaf Wintermann on 11.08.23.
//

#import <Cocoa/Cocoa.h>
#import "OutlineViewController.h"
#import "SettingsController.h"
#import "LogWindowController.h"

#import "xmpp.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readonly) Xmpp *xmpp;

@property (readonly) NSMutableDictionary *conversations;

@property (readonly) NSMutableDictionary *presence;

@property (strong) SettingsController *settingsController;
@property (strong) LogWindowController *logWindowController;

@property (strong) IBOutlet NSPopUpButton *statusButton;

@property int unread;


- (NSString*) appConfigFilePath: (NSString*)fileName;

- (void) setStatus:(int)status xmpp:(Xmpp*)xmpp;

- (NSString*) xidStatusIcon:(NSString*)xid;

- (NSDictionary*) xidStatus:(NSString*)xid;

- (NSString*) xidAlias:(NSString*)xid;

- (void) addUnread:(int)num;

- (void) handleXmppMessage:(const char*)msg_body from:(const char*)from session:(XmppSession*)session xmpp:(Xmpp*)xmpp;

- (void) handlePresence:(const char*)from status:(const char*)status xmpp:(Xmpp*)xmpp;

- (void) handleChatstate:(const char*)from state:(enum XmppChatstate)state;

- (void) handleSecureStatus:(Boolean)status from:(const char*)from xmpp:(Xmpp*)xmpp;

- (void) handleNewFingerprint:(unsigned char*)fingerprint length:(size_t)len from:(const char*)from xmpp:(Xmpp*)xmpp;

- (void) handleOtrError:(uint64_t)error from:(const char*)from xmpp:(Xmpp*)xmpp;

- (void) refreshContactList;

- (void) openConversation:(Contact*)contact;

- (void) updateConversationAlias:(NSString*)xid newAlias:(NSString*)alias;

- (void) startXmpp;


- (IBAction) menuPreferences:(id)sender;
- (IBAction) menuDebugLog:(id)sender;
- (IBAction) menuContactList:(id)sender;

- (IBAction) statusSelected:(id)sender;

@end

enum StatusTag {
    IM4_OFFLINE = 0,
    IM4_ONLINE
};
