//
//  xmpp.h
//  IM4
//
//  Created by Olaf Wintermann on 11.08.23.
//

#ifndef xmpp_h
#define xmpp_h

#include <stdlib.h>

#include <strophe.h>

#include <libotr/proto.h>
#include <libotr/userstate.h>
#include <libotr/message.h>
#include <libotr/privkey.h>

#include <pthread.h>
#include <sys/event.h>
#include <sys/time.h>

typedef struct XmppEvent XmppEvent;

typedef struct XmppSettings {
    char *jid;
    char *password;
    char *cert;
    char *key;
    long flags;
} XmppSettings;

typedef struct XmppContact {
    char *jid;
    char *name;
    char *subscription;
    char *group;
} XmppContact;

typedef struct Xmpp {
    XmppSettings  settings;
    xmpp_ctx_t    *ctx;
    xmpp_log_t    *log;
    xmpp_conn_t   *connection;
    int           fd;
    int           kqueue;
    int           enablepoll;
    int           iq_id;
    
    XmppContact *contacts;
    size_t ncontacts;
    
    OtrlUserState userstate;
} Xmpp;


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

Xmpp* XmppCreate(XmppSettings settings);

//int XmppConnect(Xmpp *xmpp);

int XmppQueryContacts(Xmpp *xmpp);

int XmppRun(Xmpp *xmpp);

void XmppCall(Xmpp *xmpp, xmpp_callback_func cb, void *userdata);

#endif /* xmpp_h */
