//
//  app.m
//  IM4
//
//  Created by Olaf Wintermann on 12.08.23.
//

#import <Foundation/Foundation.h>

#import "AppDelegate.h"

#import "app.h"




@interface AppCallback : NSObject {
    app_func callback;
    void     *userdata;
}

- (id) initWithCallback:(app_func)func userdata:(void*)userdata;

- (void) callMainThread;

- (void) mainThread:(id)n;

@end





@implementation AppCallback

- (id) initWithCallback:(app_func)func userdata:(void*)userdata {
    self->callback = func;
    self->userdata = userdata;
    return self;
}

- (void) callMainThread {
    [self performSelectorOnMainThread:@selector(mainThread:)
                                   withObject:nil
                                waitUntilDone:NO];
}

- (void) mainThread:(id)n {
    callback(userdata);
}

@end


void app_call_mainthread(app_func func, void *userdata) {
    AppCallback *cb = [[AppCallback alloc]initWithCallback:func userdata:userdata];
    [cb callMainThread];
    // TODO: memory management
}


static void mt_app_refresh_contactlist(void *xmpp) {
    // TODO: xmpp currently unused, maybe we want to pass it to the appDelegate, when multiple xmpp accounts are supported
    AppDelegate *appDelegate = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [appDelegate refreshContactList];
}

void app_refresh_contactlist(void *xmpp) {
    app_call_mainthread(mt_app_refresh_contactlist, xmpp);
}
