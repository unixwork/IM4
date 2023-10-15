//
//  xmpp.c
//  IM4
//
//  Created by Olaf Wintermann on 11.08.23.
//

#include "xmpp.h"

#include "app.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <pthread.h>
#include <poll.h>

#include "otr.h"


// TODO: list of all accounts
static Xmpp *im_account;


Xmpp* XmppCreate(XmppSettings settings) {
    xmpp_log_t *log = xmpp_get_default_logger(XMPP_LEVEL_DEBUG);
    xmpp_ctx_t *ctx = xmpp_ctx_new(NULL, log);
    
    Xmpp* xmpp = malloc(sizeof(Xmpp));
    memset(xmpp, 0, sizeof(Xmpp));
    xmpp->settings = settings;
    xmpp->log = log;
    xmpp->ctx = ctx;
    
    xmpp->userstate = otrl_userstate_create();
    
    char *privkey_file = app_configfile("otr.private_key");
    gcry_error_t otrerr = otrl_privkey_read(xmpp->userstate, privkey_file);
    printf("otrl_privkey_read: %u\n", otrerr);
    free(privkey_file);
    
    char *instancetags_file = app_configfile("otr.instance_tags");
    otrerr = otrl_instag_read(xmpp->userstate, instancetags_file);
    printf("otrl_instag_read: %u\n", otrerr);
    free(instancetags_file);
    
    return xmpp;
}

static int message_cb(xmpp_conn_t *conn, xmpp_stanza_t *stanza, void *userdata) {
    Xmpp *xmpp = userdata;
    
    const char *type = xmpp_stanza_get_type(stanza);
    if(type && !strcmp(type, "error")) {
        printf("message_cb: type = error\n");
        return 1;
    }
    
    const char *from = xmpp_stanza_get_attribute(stanza, "from");
    if(!from) {
        printf("message_cb: missing from attribute\n");
        return 1;
    }
    
    xmpp_stanza_t *body = xmpp_stanza_get_child_by_name(stanza, "body");
    if(!body) {
        printf("message_cb: no body\n");
        return 1;
    }
    
    // debug output
    char *body_text = xmpp_stanza_get_text(body);
    printf("message_cb: msg from %s: %s\n", from, body_text);
    
    if(body_text) {
        size_t len = strlen(body_text);
        char *decrypt_msg = NULL;
        char *user_msg = body_text;
        if(len > 4 && !memcmp(body_text, "?OTR", 4)) {
            int otr_err;
            decrypt_msg = decrypt_message(xmpp, from, body_text, &otr_err);
            user_msg = decrypt_msg;
            
            if(otr_err == 1) {
                printf("internal otr message\n");
                // check conversation encryption status
                ConnContext *root = xmpp->userstate->context_root;
                ConnContext *child = root->recent_rcvd_child;
                
                // xmpp res not supported yet
                char *msg_from = strdup(from);
                //char *res = strchr(msg_from, '/');
                //if(res) {
                //    *res = 0;
                //}
                
                if(child && child->username && !strcmp(child->username, msg_from)) {
                    if(child->msgstate == OTRL_MSGSTATE_FINISHED) {
                        app_update_secure_status(xmpp, msg_from, false);
                    }
                }
                
                free(msg_from);
            }
        }
        
        if(user_msg) {
            app_message(xmpp, user_msg, from);
        }
        
        free(body_text);
        if(decrypt_msg) {
            free(decrypt_msg);
        }
    }
    
    return 1;
}

static int reply_cb(xmpp_conn_t *conn, xmpp_stanza_t *stanza, void *userdata) {
    XmppQuery *xquery = userdata;
    
    const char *type = xmpp_stanza_get_type(stanza);
    if(!strcmp(type, "error")) {
        fprintf(stderr, "query %s failed", xquery->id);
    } else {
        xmpp_stanza_t *query = xmpp_stanza_get_child_by_name(stanza, "query");
        
        size_t contactsAlloc = 32;
        size_t contactsNum = 0;
        XmppContact *contacts = calloc(contactsAlloc, sizeof(XmppContact));
        
        printf("BEGIN CONTACTS\n");
        for (xmpp_stanza_t *item = xmpp_stanza_get_children(query);item;item = xmpp_stanza_get_next(item)) {
            const char *contactName = xmpp_stanza_get_attribute(item, "name");
            const char *contactJid = xmpp_stanza_get_attribute(item, "jid");
            const char *contactSub = xmpp_stanza_get_attribute(item, "subscription");
            printf(" contact jid=%s name=%s subscription=%s\n", contactJid, contactName, contactSub);
            
            if(!contactJid) {
                continue;
            }
            
            if(contactsNum >= contactsAlloc) {
                contactsAlloc += 32;
                contacts = realloc(contacts, contactsAlloc * sizeof(XmppContact));
            }
            
            XmppContact contact;
            contact.name = contactName ? strdup(contactName) : NULL;
            contact.jid = strdup(contactJid);
            contact.subscription = contactSub ? strdup(contactSub) : NULL;
            contact.group = NULL;
            contacts[contactsNum] = contact;
            
            contactsNum++;
        }
        
        if(xquery->xmpp->contacts) {
            free(xquery->xmpp->contacts);
        }
        xquery->xmpp->contacts = contacts;
        xquery->xmpp->ncontacts = contactsNum;
        
        printf("END\n");
        app_refresh_contactlist(xquery->xmpp);
    }
    
    
    free(xquery->id);
    free(xquery);
    return 0;
}

static int presence_cb(xmpp_conn_t *conn, xmpp_stanza_t *stanza, void *userdata) {
    Xmpp *xmpp = userdata;
    
    const char *type = xmpp_stanza_get_attribute(stanza, "type");
    const char *from = xmpp_stanza_get_attribute(stanza, "from");
    
    printf("presence: %s\n", from);
    app_handle_presence(xmpp, from, type);
    
    return 1;
}

static void query_conatcts(Xmpp *xmpp, XmppQuery *xquery) {
    xmpp_stanza_t *iq = xmpp_iq_new(xmpp->ctx, "get", xquery->id);
    xmpp_stanza_t *query = xmpp_stanza_new(xmpp->ctx);
    xmpp_stanza_set_name(query, "query");
    xmpp_stanza_set_ns(query, XMPP_NS_ROSTER);
    xmpp_stanza_add_child(iq, query);


    xmpp_id_handler_add(xmpp->connection, reply_cb, xquery->id, xquery);
    xmpp_send(xmpp->connection, iq);
    
    xmpp_stanza_release(query);
    xmpp_stanza_release(iq);
    
}

static void connect_cb(
        xmpp_conn_t *conn,
        xmpp_conn_event_t status,
        int error,
        xmpp_stream_error_t *stream_error,
        void *userdata)
{
    Xmpp *xmpp = userdata;
    
    if(status == XMPP_CONN_CONNECT) {
        xmpp_handler_add(conn, message_cb, NULL, "message", NULL, xmpp);
        xmpp_handler_add(conn, presence_cb, NULL, "presence", NULL, xmpp);
        
        // move to other func
        xmpp_stanza_t *im_status = xmpp_presence_new(xmpp->ctx);
        xmpp_send(conn, im_status);
        xmpp_stanza_release(im_status);
        
        // test
        XmppQueryContacts(xmpp);
        
        // set app status
        app_set_status(xmpp, 1);
    }
    
    xmpp->enablepoll = 1;
}

int socketopt_cb(xmpp_conn_t *conn, void *sock) {
    im_account->fd = *((int*)sock);
    return 0;
}

static int session_xmpp_connect(Xmpp *xmpp) {
    xmpp_conn_t *connection = xmpp_conn_new(xmpp->ctx);
    xmpp_conn_set_flags(connection, xmpp->settings.flags);
    
    // TODO: replace im_account with threadsafe list
    im_account = xmpp;
    
    xmpp_conn_set_sockopt_callback(connection, socketopt_cb);
    
    
    xmpp_conn_set_jid(connection, xmpp->settings.jid);
    xmpp_conn_set_pass(connection, xmpp->settings.password);
    
    char *host = NULL;
    unsigned short port = 0;
    
    if(xmpp_connect_client(connection, host, port, connect_cb, xmpp) != XMPP_EOK) {
        // TODO: free
        return 1;
    }
    
    xmpp->connection = connection;
    
    return 0;
}

/*
int XmppConnect(Xmpp *xmpp) {
    XmppCall(xmpp, (xmpp_callback_func)mt_xmpp_connect, xmpp);
    return 0;
}
*/

int XmppQueryContacts(Xmpp *xmpp) {
    XmppQuery *query = malloc(sizeof(XmppQuery));
    query->xmpp = xmpp;
    
    char idbuf[16];
    snprintf(idbuf, 16, "%d", ++xmpp->iq_id);
    
    query->id = strdup(idbuf);
    
    query_conatcts(xmpp, query);
    
    return 0;
}

static void* xmpp_run_thread(void *data) {
    Xmpp *xmpp = data;
    xmpp->running = 1;
    
    /*
    struct pollfd pfd[1];
    pfd[0].fd = xmpp->fd;
    pfd[0].events = POLLIN;
    */
    
    if(session_xmpp_connect(xmpp)) {
        return NULL;
    }
    printf("xmpp connected\n");
    
    while(xmpp->running) {
        xmpp_run_once(xmpp->ctx, 10);
        if(xmpp_conn_is_disconnected(xmpp->connection)) {
            break;
        }
        
        if(xmpp->enablepoll) {
            int queuelen = xmpp_conn_send_queue_len(xmpp->connection);
            if(queuelen == 0) {
                struct timespec timeout;
                timeout.tv_nsec = 0;
                timeout.tv_sec = 10000;
                struct kevent events[64];
                struct kevent changes[128];
                int numchanges = 0;
                
                struct kevent kev;
                EV_SET(&kev, xmpp->fd, EVFILT_READ, EV_ADD, 0, 0, NULL);
                kevent(xmpp->kqueue, &kev, 1, NULL, 0, NULL);
                
                int nev = kevent(xmpp->kqueue, changes, numchanges, events, 64, &timeout);
                for(int i=0;i<nev;i++) {
                    XmppEvent *xmpp_event = events[i].udata;
                    if(xmpp_event) {
                        xmpp_event->callback(xmpp, xmpp_event->userdata);
                        free(xmpp_event);
                        
                    }
                }
                
                /*
                if(poll(pfd, 1, 10000) < 0) {
                    perror("poll");
                    break;
                }
                */
            }
        }
    }
    
    return NULL;
}

int XmppRun(Xmpp *xmpp) {
    xmpp->kqueue = kqueue();
    if(xmpp->kqueue < 0) {
        return 1;
    }
    
    pthread_t t;
    if(pthread_create(&t, NULL, xmpp_run_thread, xmpp)) {
        perror("pthread_create");
        return 1;
    }
    
    pthread_detach(t);
    
    return 0;
}

static  void xmpp_stop_cb(Xmpp *xmpp, void *unused) {
    char *debug = unused;
    xmpp_stop(xmpp->ctx);
    xmpp->running = 0;
    
    // TODO: free stuff
}

static int debug_ctn = 0;

void XmppStopAndDestroy(Xmpp *xmpp) {
    char *debugmsg = malloc(100);
    snprintf(debugmsg, 100, "%d", debug_ctn++);
    XmppCall(xmpp, xmpp_stop_cb, debugmsg);
}

void XmppCall(Xmpp *xmpp, xmpp_callback_func cb, void *userdata) {
    XmppEvent *ev = malloc(sizeof(XmppEvent));
    ev->callback = cb;
    ev->userdata = userdata;
    
    struct kevent kev;
    EV_SET(&kev, xmpp->fd, EVFILT_USER, EV_ADD|EV_ONESHOT, NOTE_TRIGGER, 0, ev);
    kevent(xmpp->kqueue, &kev, 1, NULL, 0, NULL);
    
}

typedef struct {
    char *to;
    char *message;
    bool encrypt;
} xmpp_msg;

void Xmpp_Send(Xmpp *xmpp, const char *to, const char *message) {
    char idbuf[16];
    snprintf(idbuf, 16, "%d", ++xmpp->iq_id);
    
    xmpp_stanza_t *msg = xmpp_message_new(xmpp->ctx, "chat", to, idbuf);
    
    xmpp_message_set_body(msg, message);
    xmpp_send(xmpp->connection, msg);
    xmpp_stanza_release(msg);
}

static void send_xmpp_msg(Xmpp *xmpp, void *userdata) {
    xmpp_msg *msg = userdata;
    
    char *text = NULL;
    if(msg->encrypt) {
        int err;
        text = encrypt_message(xmpp, msg->to, msg->message, &err);
    } else {
        text = msg->message;
    }
    
    if(text) {
        Xmpp_Send(xmpp, msg->to, text);
    }
    
    if(text != msg->message) {
        free(text);
    }
    
    free(msg->to);
    free(msg->message);
    free(msg);
}

void XmppMessage(Xmpp *xmpp, const char *to, const char *message, bool encrypt) {
    xmpp_msg *msg = malloc(sizeof(xmpp_msg));
    msg->to = strdup(to);
    msg->message = strdup(message);
    msg->encrypt = encrypt;
    XmppCall(xmpp, send_xmpp_msg, msg);
}

static void init_xmpp_otr(Xmpp *xmpp, void *userdata) {
    start_otr(xmpp, userdata);
    free(userdata);
}

void XmppStartOtr(Xmpp *xmpp, const char *recipient) {
    char *r = strdup(recipient);
    XmppCall(xmpp, init_xmpp_otr, r);
}

static void stop_xmpp_otr(Xmpp *xmpp, void *userdata) {
    stop_otr(xmpp, userdata);
    free(userdata);
}

void XmppStopOtr(Xmpp *xmpp, const char *recipient) {
    char *r = strdup(recipient);
    XmppCall(xmpp, stop_xmpp_otr, r);
}
