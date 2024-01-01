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
    _unread = 0;
    
    //_outlineViewController = [[OutlineViewController alloc]init];
    //[_contactList setDataSource:_outlineViewController];
    [_contactList setDelegate:_outlineViewController];
    
    
    _presence = [[NSMutableDictionary alloc]init];
    
    // config
    _settingsController = [[SettingsController alloc]initSettings];
    [self startXmpp];
    
    //[[[NSApplication sharedApplication] dockTile] setBadgeLabel:@""];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [_settingsController storeSettings];
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

- (void) addUnread:(int)num {
    _unread += num;
    NSString *badge = nil;
    if(_unread != 0) {
        badge = [@(_unread) stringValue];
    }
    [[[NSApplication sharedApplication] dockTile] setBadgeLabel:badge];
}

- (void) setStatus:(int)status xmpp:(Xmpp*)xmpp {
    // xmpp currently unused, because only one xmpp conn is supported
    
    switch(status) {
        case 0: {
            [_window setTitle:@"🔴 IM4"];
            
            [_presence removeAllObjects];
            [self refreshContactList];
            
            for(id key in _conversations) {
                ConversationWindowController *conv = [_conversations objectForKey:key];
                [conv updateStatus];
            }
            
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

- (NSString*) xidStatusIcon:(NSString*)xid {
    NSDictionary *statusMap = [self xidStatus:xid];
    
    return statusMap == nil || [statusMap count] == 0 ? @"🔴" : @"🟢";
}

- (NSDictionary*) xidStatus:(NSString*)xid {
    return [_presence valueForKey:xid];
}

- (NSString*) xidAlias:(NSString*)xid {
    NSString *alias = [_outlineViewController contactName:xid];
    return alias != nil ? alias : xid;
}

- (void) handleXmppMessage:(const char*)msg_body from:(const char*)from xmpp:(Xmpp*)xmpp {
    char *res = strchr(from, '/');
    size_t from_len;
    NSString *resource = @"";
    if(res) {
        from_len = res - from;
        resource = [[NSString alloc]initWithUTF8String:res];
    } else {
        from_len = strlen(from);
    }
    
    NSString *xid = [[NSString alloc]initWithBytes:from length:from_len encoding:NSUTF8StringEncoding];
    NSString *alias = [_settingsController getAlias:xid];
    NSString *message_text = [[NSString alloc]initWithUTF8String:msg_body];
    
    if(!alias) {
        alias = xid;
    }
    
    ConversationWindowController *conversation = [_conversations objectForKey:xid];
    if(!conversation) {
        conversation = [[ConversationWindowController alloc]initConversation:xid alias:alias xmpp:_xmpp];
        [_conversations setObject:conversation forKey:xid];
    }
    [conversation showWindow:nil];
    [conversation addReceivedMessage:message_text resource:resource];
}

- (void) handlePresence:(const char*)from status:(const char*)status xmpp:(Xmpp*)xmpp {
    char *res = strchr(from, '/');
    size_t from_len;
    NSString *resource = @"";
    if(res) {
        from_len = res - from;
        resource = [[NSString alloc]initWithUTF8String:res];
    } else {
        from_len = strlen(from);
    }
    
    NSString *xid = [[NSString alloc]initWithBytes:from length:from_len encoding:NSUTF8StringEncoding];
    if(!status) {
        status = "";
    }
    NSString *s = [[NSString alloc]initWithUTF8String:status];
    
    // _presence contains two nested NSMutableDictionary objects
    // The first dictionary from _presence uses the xid without the resource part as key
    // and contains a dictionary with the resource part as key and the status string as value.
    NSMutableDictionary *xid_status = [_presence valueForKey:xid];
    if(!strcmp(status, "unavailable")) {
        if(xid_status) {
            [xid_status removeObjectForKey:resource];
        }
        s = nil;
    } else {
        // if _presence doesn't contain an object for the xid, create a
        // mutable dictionary and add it
        if(xid_status == nil) {
            xid_status = [[NSMutableDictionary alloc]init];
            [_presence setObject:xid_status forKey:xid];
        }
        // set the status for the resource
        [xid_status setObject:s forKey:resource];
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
    char *res = strchr(from, '/');
    size_t from_len;
    NSString *resource = @"";
    if(res) {
        from_len = res - from;
        resource = [[NSString alloc]initWithUTF8String:res];
    } else {
        from_len = strlen(from);
    }
    
    NSString *xid = [[NSString alloc]initWithBytes:from length:from_len encoding:NSUTF8StringEncoding];
    NSString *alias = [_settingsController getAlias:xid];
    if(!alias) {
        alias = xid;
    }
    ConversationWindowController *conversation = [_conversations objectForKey:xid];
    if(!conversation) {
        conversation = [[ConversationWindowController alloc]initConversation:xid alias:alias xmpp:_xmpp];
        [_conversations setObject:conversation forKey:xid];
    }
    [conversation showWindow:nil];
    [conversation setSecure:status session:resource];
}

- (void) handleNewFingerprint:(unsigned char*)fingerprint length:(size_t)len from:(const char*)from xmpp:(Xmpp*)xmpp {
    char *res = strchr(from, '/');
    size_t from_len;
    NSString *resource = @"";
    if(res) {
        from_len = res - from;
        resource = [[NSString alloc]initWithUTF8String:res];
    } else {
        from_len = strlen(from);
    }
    
    NSString *xid = [[NSString alloc]initWithBytes:from length:from_len encoding:NSUTF8StringEncoding];
    NSString *alias = [_settingsController getAlias:xid];
    if(!alias) {
        alias = xid;
    }
    ConversationWindowController *conversation = [_conversations objectForKey:xid];
    if(!conversation) {
        conversation = [[ConversationWindowController alloc]initConversation:xid alias:alias xmpp:_xmpp];
        [_conversations setObject:conversation forKey:xid];
    }
    [conversation showWindow:nil];
    
    NSString *ns_from = [[NSString alloc]initWithUTF8String:from];
    
    size_t fpstr_len = len * 2 + len/4 + 1;
    char *fpstr = malloc(fpstr_len);
    char *fpstr_pos = fpstr;
    for(int i=0;i<len;i++) {
        int b = (i+1)%4;
        char *t = i > 0 && b == 0 ? " " : "";
        size_t w = snprintf(fpstr_pos, fpstr_len - (fpstr_pos - fpstr), "%x%s", (int)fingerprint[i], t);
        fpstr_pos += w;
    }
    NSString *ns_fingerprint = [[NSString alloc]initWithUTF8String: fpstr];
    
    
    [conversation newFingerprint:ns_fingerprint from:ns_from];
}

- (void) handleOtrError:(uint64_t)error from:(const char*)from xmpp:(Xmpp*)xmpp {
    char *res = strchr(from, '/');
    size_t from_len;
    NSString *resource = @"";
    if(res) {
        from_len = res - from;
        resource = [[NSString alloc]initWithUTF8String:res];
    } else {
        from_len = strlen(from);
    }
    NSString *nsfrom = [[NSString alloc]initWithUTF8String:from];
    
    NSString *xid = [[NSString alloc]initWithBytes:from length:from_len encoding:NSUTF8StringEncoding];
    NSString *alias = [_settingsController getAlias:xid];
    if(!alias) {
        alias = xid;
    }
    ConversationWindowController *conversation = [_conversations objectForKey:xid];
    if(!conversation) {
        conversation = [[ConversationWindowController alloc]initConversation:xid alias:alias xmpp:_xmpp];
        [_conversations setObject:conversation forKey:xid];
    }
    [conversation showWindow:nil];
    [conversation otrError:error from:nsfrom];
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
        conversation = [[ConversationWindowController alloc]initConversation:contact.xid alias:contact.name xmpp:_xmpp];
        [_conversations setObject:conversation forKey:contact.xid];
    }
    [conversation showWindow:nil];
}

- (void) updateConversationAlias:(NSString*)xid newAlias:(NSString*)alias {
    ConversationWindowController *conversation = [_conversations objectForKey:xid];
    if(conversation) {
        conversation.alias = alias;
    }
}

- (void) startXmpp {
    if(_xmpp) {
        XmppStopAndDestroy(_xmpp);
        [_outlineViewController clearContacts];
        [_contactList reloadData];
    }
    _xmpp = _settingsController.xmpp;
    if(_xmpp) {
        XmppRun(_xmpp);
    }
    [self setStatus:0 xmpp:_xmpp];
}

- (IBAction) menuPreferences:(id)sender {
    [_settingsController showWindow:nil];
}

@end
