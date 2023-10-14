//
//  AppDelegate.m
//  IM4
//
//  Created by Olaf Wintermann on 11.08.23.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#import "AppDelegate.h"
#import "ConversationWindowController.h"
#import "SettingsController.h"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSOutlineView *contactList;
@property (strong) IBOutlet OutlineViewController *outlineViewController;
@property (strong) IBOutlet NSMenu *contactsContextMenu;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _conversations = [[NSMutableDictionary alloc]init];
    
    //_outlineViewController = [[OutlineViewController alloc]init];
    //[_contactList setDataSource:_outlineViewController];
    [_contactList setDelegate:_outlineViewController];
    
    
    _presence = [[NSMutableDictionary alloc]init];
    
    // config
    _settingsController = [[SettingsController alloc]initSettings];
    _xmpp = _settingsController.xmpp;
    if(_xmpp) {
        XmppRun(_xmpp);
    }
    
    [self setStatus:0 xmpp:_xmpp];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag{
    if(!flag) {
        [_window setIsVisible:YES];
    }
    return YES;
}

- (void) setStatus:(int)status xmpp:(Xmpp*)xmpp {
    // xmpp currently unused, because only one xmpp conn is supported
    
    switch(status) {
        case 0: {
            [_window setTitle:@"🔴 IM4"];
            break;
        }
        case 1: {
            [_window setTitle:@"🟢 IM4"];
            break;
        }
        case 2: {
            [_window setTitle:@"🟡 IM4"];
            break;
        }
    }
}

- (NSString*) xidStatus:(NSString*)xid {
    return [_presence objectForKey:xid];
}

- (NSString*) xidStatusIcon:(NSString*)xid {
    NSString *status = [self xidStatus:xid];
    return status == nil ? @"🔴" : @"🟢";
}

- (NSString*) xidAlias:(NSString*)xid {
    NSString *alias = [_outlineViewController contactName:xid];
    return alias != nil ? alias : xid;
}

- (void) handleXmppMessage:(const char*)msg_body from:(const char*)from xmpp:(Xmpp*)xmpp {
    char *res = strchr(from, '/');
    if(res) {
        res[0] = '\0';
    }
    
    NSString *xid = [[NSString alloc]initWithUTF8String:from];
    NSString *message_text = [[NSString alloc]initWithUTF8String:msg_body];
    
    ConversationWindowController *conversation = [_conversations objectForKey:xid];
    if(!conversation) {
        conversation = [[ConversationWindowController alloc]initConversation:xid xmpp:_xmpp];
        [_conversations setObject:conversation forKey:xid];
    }
    [conversation addReceivedMessage:message_text];
    [conversation showWindow:nil];
}

- (void) handlePresence:(const char*)from status:(const char*)status xmpp:(Xmpp*)xmpp {
    NSString *xid = [[NSString alloc]initWithUTF8String:from];
    if(!status) {
        status = "";
    }
    NSString *s = [[NSString alloc]initWithUTF8String:status];
    
    if(!strcmp(status, "unavailable")) {
        [_presence removeObjectForKey:xid];
        s = nil;
    } else {
        [_presence setObject:s forKey:xid];
    }
    
    if([_outlineViewController updatePresence:s xid:xid]) {
        [_contactList reloadData];
    }
    
    ConversationWindowController *conversation = [_conversations objectForKey:xid];
    if(conversation != nil) {
        [conversation updateStatus];
    }
}

- (void) handleSecureStatus:(Boolean)status from:(const char*)from xmpp:(Xmpp*)xmpp {
    NSString *xid = [[NSString alloc]initWithUTF8String:from];
    
    ConversationWindowController *conversation = [_conversations objectForKey:xid];
    if(conversation) {
        [conversation setSecure:status];
    }
}

- (void) refreshContactList {
    printf("refresh contact list\n");
    
    [_outlineViewController refreshContacts:_xmpp presence:_presence];
    [_contactList reloadData];
}

- (void) openConversation:(Contact*)contact {
    printf("Open Conversation: %s\n", [contact.xid UTF8String]);
    
    ConversationWindowController *conversation = [_conversations objectForKey:contact.xid];
    if(conversation == nil) {
        conversation = [[ConversationWindowController alloc]initConversation:contact.xid xmpp:_xmpp];
        [_conversations setObject:conversation forKey:contact.xid];
    }
    [conversation showWindow:nil];
}


- (IBAction) menuPreferences:(id)sender {
    if(_settingsController == nil) {
        _settingsController = [[SettingsController alloc]initWithWindowNibName:@"SettingsController"];
    }
    [_settingsController showWindow:nil];
}

@end
