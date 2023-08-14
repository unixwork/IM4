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
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [app refreshContactList];
}

void app_refresh_contactlist(void *xmpp) {
    app_call_mainthread(mt_app_refresh_contactlist, xmpp);
}

typedef struct {
    void *xmpp;
    int status;
} app_set_xmpp_status;

static void mt_app_set_status(void *userdata) {
    app_set_xmpp_status *st = userdata;
    void *xmpp = st->xmpp;
    int status = st->status;
    free(st);
    
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [app setStatus:status xmpp:xmpp];
}

void app_set_status(void *xmpp, int status) {
    app_set_xmpp_status *st = malloc(sizeof(app_set_xmpp_status));
    st->xmpp = xmpp;
    st->status = status;
    app_call_mainthread(mt_app_set_status, st);
}


typedef struct {
    void *xmpp;
    char *from;
    char *status
} app_presence;

void mt_app_handle_presence(void *userdata) {
    app_presence *p = userdata;
    
    char *res = strchr(p->from, '/');
    if(res) {
        res[0] = 0;
    }
    
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [app handlePresence:p->from status:p->status xmpp:p->xmpp];
    
    free(p->from);
    free(p->status);
    free(p);
}



void app_handle_presence(void *xmpp, const char *from, const char *status) {
    app_presence *p = malloc(sizeof(app_presence));
    p->xmpp = xmpp;
    p->from = strdup(from);
    p->status = status ? strdup(status) : NULL;
    app_call_mainthread(mt_app_handle_presence, p);
}

typedef struct {
    void *xmpp;
    char *msg_body;
    char *from;
} app_recv_message;

static void mt_app_message(void *userdata) {
    app_recv_message *msg = userdata;
    
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [app handleXmppMessage:msg->msg_body from:msg->from xmpp:msg->xmpp];
    
    free(msg->from);
    free(msg->msg_body);
    free(msg);
}

void app_message(void *xmpp, const char *msg_body, const char *from) {
    app_recv_message *msg = malloc(sizeof(app_recv_message));
    msg->xmpp = xmpp;
    msg->msg_body = strdup(msg_body);
    msg->from = strdup(from);
    app_call_mainthread(mt_app_message, msg);
}
