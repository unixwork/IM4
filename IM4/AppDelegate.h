//
//  AppDelegate.h
//  IM4
//
//  Created by Olaf Wintermann on 11.08.23.
//

#define IM4_APPNAME "IM4"
#define IM4_APPNAME_NS @ IM4_APPNAME

#import <Cocoa/Cocoa.h>
#import "OutlineViewController.h"

#import "xmpp.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readonly) Xmpp *xmpp;

@property (readonly) NSMutableDictionary *conversations;


- (NSString*) appConfigFilePath: (NSString*)fileName;

- (void) refreshContactList;

- (void) openConversation:(Contact*)contact;

@end

