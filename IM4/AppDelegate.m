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

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSOutlineView *contactList;
@property (strong) IBOutlet OutlineViewController *outlineViewController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _conversations = [[NSMutableDictionary alloc]init];
    
    //_outlineViewController = [[OutlineViewController alloc]init];
    //[_contactList setDataSource:_outlineViewController];
    
    // config
    NSString *configFilePath = [self appConfigFilePath:@"config.plist"];
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:configFilePath];
    
    NSString *jid = [config valueForKey:@"jid"];
    NSString *password = [config valueForKey:@"password"];
    
    if(jid && password) {
        XmppSettings settings = {0};
        settings.jid = strdup([jid UTF8String]);
        settings.password = strdup([password UTF8String]);
        
        _xmpp = XmppCreate(settings);
        XmppRun(_xmpp);
    }
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

- (NSString*) appConfigFilePath: (NSString*)fileName {
    NSArray *path = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    if([path count] == 0) {
        return nil;
    }
    
    NSString *configDir = [path objectAtIndex:0];
    return [configDir stringByAppendingFormat:@"/%@/%@", IM4_APPNAME_NS, fileName];
}

- (void) refreshContactList {
    printf("refresh contact list\n");
    
    [_outlineViewController refreshContacts:_xmpp];
    [_contactList reloadData];
}

- (void) openConversation:(Contact*)contact {
    printf("Open Conversation: %s\n", [contact.xid UTF8String]);
    
    ConversationWindowController *conversation = [_conversations objectForKey:contact.xid];
    if(conversation == nil) {
        conversation = [[ConversationWindowController alloc]initConversation:contact.xid];
        [_conversations setObject:conversation forKey:contact.xid];
    }
    [conversation showWindow:nil];
}

@end
