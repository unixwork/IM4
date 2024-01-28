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

#ifndef xmpp_h
#define xmpp_h

#include <stdlib.h>
#include <stdbool.h>

#include <strophe.h>

#include <libotr/proto.h>
#include <libotr/userstate.h>
#include <libotr/message.h>
#include <libotr/privkey.h>

#include <pthread.h>
#include <sys/event.h>
#include <sys/time.h>

#include <libotr/proto.h>
#include <libotr/userstate.h>
#include <libotr/message.h>
#include <libotr/privkey.h>

typedef struct XmppEvent        XmppEvent;
typedef struct XmppSession      XmppSession;
typedef struct XmppConversation XmppConversation;
typedef struct Xmpp             Xmpp;

typedef struct XmppSettings {
    char *jid;
    char *password;
    char *cert;
    char *key;
    char *alias;
    char *resource;
    char *host;
    short port;
    long flags;
} XmppSettings;

typedef struct XmppContact {
    char *jid;
    char *name;
    char *subscription;
    char *group;
} XmppContact;

struct XmppSession {
    /*
     * parent conversation object
     */
    XmppConversation *conversation;
    
    /*
     * resource part
     */
    char *resource;
    
    bool online;
    bool otr;
    bool enabled;
};

/*
 * represents a conversation window with one person (xid)
 */
struct XmppConversation {
    /*
     * recipient xid
     */
    char *xid;
    
    /*
     * dummy session without resource string
     */
    XmppSession *nores;
    
    /*
     * recipient array
     */
    XmppSession **sessions;
    
    /*
     * number of XmppSession elements
     */
    size_t nsessions;
    
    /*
     * number of XmppSession elements allocated
     */
    size_t snalloc;
    
    /*
     * the active sessions were manually selected
     */
    bool sessionselected;
    
    /*
     * custom user data 1
     */
    void *userdata1;
    
    /*
     * custom user data 2
     */
    void *userdata2;
};

struct Xmpp {
    XmppSettings  settings;
    xmpp_ctx_t    *ctx;
    xmpp_log_t    *log;
    xmpp_conn_t   *connection;
    char          *xid;
    int           fd;
    int           kqueue;
    int           enablepoll;
    int           iq_id;
    int           running;
    
    /*
     * xmpp roster
     */
    XmppContact *contacts;
    size_t ncontacts;
    
    /*
     * conversations array
     */
    XmppConversation **conversations;
    
    /*
     * number of conversation elements
     */
    size_t nconversations;
    
    /*
     * number of XmppConversation elements allocated
     */
    size_t conversationsalloc;
    
    OtrlUserState userstate;
};



enum XmppChatstate {
    XMPP_CHATSTATE_ACTIVE = 0,
    XMPP_CHATSTATE_COMPOSING,
    XMPP_CHATSTATE_PAUSED,
    XMPP_CHATSTATE_INACTIVE,
    XMPP_CHATSTATE_GONE
};


typedef void(*xmpp_callback_func)(Xmpp*, void*);


typedef struct XmppQuery {
    Xmpp       *xmpp;
    char       *id;
    // TODO: msg query
} XmppQuery;

struct XmppEvent {
    xmpp_callback_func callback;
    void *userdata;
};

xmpp_log_level_t XmppGetLogLevel(void);
void XmppSetLovLevel(xmpp_log_level_t level);

/*
 * internal logging function
 * XmppLog does not automatically append a newline character to str
 */
void XmppLog(const char *str);

Xmpp* XmppCreate(XmppSettings settings);

Xmpp* XmppRecreate(Xmpp *xmpp, XmppSettings settings);

//int XmppConnect(Xmpp *xmpp);

int XmppQueryContacts(Xmpp *xmpp);

int XmppRun(Xmpp *xmpp);

void XmppStop(Xmpp *xmpp);

void XmppCall(Xmpp *xmpp, xmpp_callback_func cb, void *userdata);

void Xmpp_Send(Xmpp *xmp, const char *to, const char *message);

void Xmpp_Send_State(Xmpp *xmpp, const char *to, enum XmppChatstate s);

void XmppMessage(Xmpp *xmpp, const char *to, const char *message, bool encrypt);

void XmppStateMessage(Xmpp *xmpp, const char *to, enum XmppChatstate state);

void XmppStartOtr(Xmpp *xmpp, const char *recipient);

void XmppStopOtr(Xmpp *xmpp, const char *recipient);

XmppSession* XmppGetSession(Xmpp *xmpp, const char *recipient);

void XmppSessionRemoveAndDestroy(XmppSession *sn);

#endif /* xmpp_h */
