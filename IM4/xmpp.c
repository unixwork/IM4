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
    
    return xmpp;
}

static int message_cb(xmpp_conn_t *conn, xmpp_stanza_t *stanza, void *userdata) {
    Xmpp *xmpp = userdata;
    
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
        xmpp_handler_add(conn, message_cb, NULL, "message", NULL, userdata);
        
        
        // move to other func
        xmpp_stanza_t *im_status = xmpp_presence_new(xmpp->ctx);
        xmpp_send(conn, im_status);
        xmpp_stanza_release(im_status);
        
        // test
        XmppQueryContacts(xmpp);
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
    
    /*
    struct pollfd pfd[1];
    pfd[0].fd = xmpp->fd;
    pfd[0].events = POLLIN;
    */
    
    if(session_xmpp_connect(xmpp)) {
        return NULL;
    }
    printf("xmpp connected\n");
    
    int running = 1;
    while(running) {
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
                        xmpp_event->callback(xmpp, xmpp_event);
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

void XmppCall(Xmpp *xmpp, xmpp_callback_func cb, void *userdata) {
    XmppEvent *ev = malloc(sizeof(XmppEvent));
    ev->callback = cb;
    ev->userdata = userdata;
    
    struct kevent kev;
    EV_SET(&kev, xmpp->fd, EVFILT_USER, 0, NOTE_TRIGGER, 0, ev);
    kevent(xmpp->kqueue, &kev, 1, NULL, 0, NULL);
}
