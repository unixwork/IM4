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

/*
 * app.c is a bridge between the C xmpp/otr part and the Objective-C part
 */

#import <Foundation/Foundation.h>

#import "AppDelegate.h"
#import "ConversationWindowController.h"

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

char* app_configfile(const char *name) {
    NSArray *path = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    if([path count] == 0) {
        return nil;
    }
    
    NSString *configDir = [path objectAtIndex:0];
    NSString *configFilePath = [configDir stringByAppendingFormat:@"/%@/%s", IM4_APPNAME_NS, name];
    
    char *cfPath = strdup([configFilePath UTF8String]);
    
    return cfPath;
}


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
    Xmpp *xmpp;
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

void app_set_status(Xmpp *xmpp, int status) {
    app_set_xmpp_status *st = malloc(sizeof(app_set_xmpp_status));
    st->xmpp = xmpp;
    st->status = status;
    app_call_mainthread(mt_app_set_status, st);
}


typedef struct {
    Xmpp *xmpp;
    char *from;
    char *status;
} app_presence;

void mt_app_handle_presence(void *userdata) {
    app_presence *p = userdata;
    
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [app handlePresence:p->from status:p->status xmpp:p->xmpp];
    
    free(p->from);
    free(p->status);
    free(p);
}

void app_handle_presence(Xmpp *xmpp, const char *from, const char *status) {
    app_presence *p = malloc(sizeof(app_presence));
    p->xmpp = xmpp;
    p->from = strdup(from);
    p->status = status ? strdup(status) : NULL;
    app_call_mainthread(mt_app_handle_presence, p);
}



typedef struct {
    Xmpp *xmpp;
    char *from;
    unsigned char *fingerprint;
    size_t fingerprint_length;
} app_newfingerprint;

void mt_app_handle_new_fingerprint(void *userdata) {
    app_newfingerprint *f = userdata;
    
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [app handleNewFingerprint:f->fingerprint length:f->fingerprint_length from:f->from session:XmppGetSession(f->xmpp, f->from) xmpp:f->xmpp];
    
    free(f->from);
    free(f->fingerprint);
    free(f);
}

void app_handle_new_fingerprint(Xmpp *xmpp, const char *from, const unsigned char *fingerprint, size_t fplen) {
    app_newfingerprint *f = malloc(sizeof(app_newfingerprint));
    f->xmpp = xmpp;
    f->from = strdup(from);
    f->fingerprint = malloc(fplen);
    memcpy(f->fingerprint, fingerprint, fplen);
    f->fingerprint_length = fplen;
    app_call_mainthread(mt_app_handle_new_fingerprint, f);
}

typedef struct {
    Xmpp *xmpp;
    char *from;
    uint64_t error;
} app_otrerror;

void mt_app_otr_error(void *userdata) {
    app_otrerror *e = userdata;
    
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [app handleOtrError:e->error from:e->from session:XmppGetSession(e->xmpp, e->from) xmpp:e->xmpp];
    
    free(e->from);
    free(e);
}

void app_otr_error(Xmpp *xmpp, const char *from, uint64_t error) {
    app_otrerror *e = malloc(sizeof(app_otrerror));
    e->xmpp = xmpp;
    e->from = strdup(from);
    e->error = error;
    app_call_mainthread(mt_app_otr_error, e);
}

typedef struct {
    Xmpp *xmpp;
    char *from;
    char *msg_body;
} app_recv_message;

static void mt_app_message(void *userdata) {
    app_recv_message *msg = userdata;
    
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [app handleXmppMessage:msg->msg_body from:msg->from session:XmppGetSession(msg->xmpp, msg->from) xmpp:msg->xmpp];
    
    free(msg->from);
    free(msg->msg_body);
    free(msg);
}

void app_message(Xmpp *xmpp, const char *from, const char *msg_body) {
    app_recv_message *msg = malloc(sizeof(app_recv_message));
    msg->xmpp = xmpp;
    msg->msg_body = strdup(msg_body);
    msg->from = strdup(from);
    app_call_mainthread(mt_app_message, msg);
}

typedef struct {
    Xmpp *xmpp;
    char *from;
    enum XmppChatstate state;
} app_chatstate_msg;

static void mt_app_chatstate(void *userdata) {
    app_chatstate_msg *st = userdata;
    
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [app handleChatstate:st->from state:st->state session:XmppGetSession(st->xmpp, st->from)];
    
    free(st->from);
    free(st);
}

void app_chatstate(Xmpp *xmpp, const char *from, enum XmppChatstate state) {
    app_chatstate_msg *st = malloc(sizeof(app_chatstate_msg));
    st->xmpp = xmpp;
    st->from = strdup(from);
    st->state = state;
    app_call_mainthread(mt_app_chatstate, st);
}

typedef struct {
    void *xmpp;
    char *from;
    bool status;
} app_secure_status;

static void mt_app_update_secure_status(void *userdata) {
    app_secure_status *s = userdata;
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [app handleSecureStatus:s->status from:s->from session:XmppGetSession(s->xmpp, s->from) xmpp:s->xmpp];
    
    free(s->from);
    free(s);
}

void app_update_secure_status(Xmpp *xmpp, const char *from, bool issecure) {
    app_secure_status *status = malloc(sizeof(app_secure_status));
    status->xmpp = xmpp;
    status->from = strdup(from);
    status->status = issecure;
    app_call_mainthread(mt_app_update_secure_status, status);
}


typedef struct {
    char *msg;
    size_t len;
} app_log_msg;

static void mt_app_add_log(void *userdata) {
    app_log_msg *msg = userdata;
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [app.logWindowController addToLog:msg->msg length:msg->len];
    
    free(msg->msg);
    free(msg);
}

void app_add_log(const char *msg, size_t len) {
    app_log_msg *log = malloc(sizeof(app_log_msg));
    log->msg = strdup(msg);
    log->len = len;
    app_call_mainthread(mt_app_add_log, log);
}
