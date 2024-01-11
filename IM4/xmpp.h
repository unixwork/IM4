//
//  xmpp.h
//  IM4
//
//  Created by Olaf Wintermann on 11.08.23.
//

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
    
    bool otr;
    bool enabled;
};

struct XmppConversation {
    /*
     * recipient xid
     */
    char *xid;
    
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


#endif /* xmpp_h */
