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

#include "xmpp.h"

#include "app.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <pthread.h>
#include <poll.h>
#include <sys/socket.h>

#include "otr.h"


// TODO: list of all accounts
static Xmpp *im_account;

static xmpp_log_level_t xmpp_log_level = XMPP_LEVEL_INFO;

xmpp_log_level_t XmppGetLogLevel(void) {
    return xmpp_log_level;
}

void XmppSetLogLevel(xmpp_log_level_t level) {
    xmpp_log_level = level;
}

void XmppLog(const char *str) {
    app_add_log(str, strlen(str));
    fprintf(stderr, "%s", str);
}

static void log_handler(void *userdata,
                        xmpp_log_level_t level,
                        const char *area,
                        const char *msg)
{
    if(level < xmpp_log_level) {
        return;
    }
    
    char *str = NULL;
    char *lvlStr = "-";
    switch(level) {
        case XMPP_LEVEL_DEBUG: lvlStr = "DEBUG"; break;
        case XMPP_LEVEL_INFO: lvlStr = "INFO"; break;
        case XMPP_LEVEL_WARN: lvlStr = "WARN"; break;
        case XMPP_LEVEL_ERROR: lvlStr = "ERROR"; break;
    }
    asprintf(&str, "%s %s: %s\n", area, lvlStr, msg);
    
    XmppLog(str);
    free(str);
}

static xmpp_log_t logf = {
    log_handler,
    NULL
};

Xmpp* XmppCreate(XmppSettings settings) {
    //xmpp_log_t *log = xmpp_get_default_logger(XMPP_LEVEL_DEBUG);
    xmpp_ctx_t *ctx = xmpp_ctx_new(NULL, &logf);
    
    Xmpp* xmpp = malloc(sizeof(Xmpp));
    memset(xmpp, 0, sizeof(Xmpp));
    xmpp->settings = settings;
    xmpp->log = &logf;
    xmpp->ctx = ctx;
    
    if(settings.jid) {
        if(xmpp->settings.resource && strlen(xmpp->settings.resource) > 0) {
            asprintf(&xmpp->xid, "%s/%s", xmpp->settings.jid, xmpp->settings.resource);
        } else {
            xmpp->xid = strdup(xmpp->settings.jid);
        }
        
        xmpp->userstate = otrl_userstate_create();
        
        char *privkey_file = app_configfile("otr.private_key");
        gcry_error_t otrerr = otrl_privkey_read(xmpp->userstate, privkey_file);
        free(privkey_file);
        
        char *fingerprints_file = app_configfile("otr.fingerprints");
        otrerr = otrl_privkey_read_fingerprints(xmpp->userstate, fingerprints_file, NULL, NULL);
        
        char *instancetags_file = app_configfile("otr.instance_tags");
        otrerr = otrl_instag_read(xmpp->userstate, instancetags_file);
        free(instancetags_file);
    }
    
    return xmpp;
}

void XmppRecreate(Xmpp *xmpp, XmppSettings settings) {
    xmpp_ctx_t *ctx = xmpp_ctx_new(NULL, &logf);
    
    xmpp->ctx = ctx;
    xmpp->log = &logf;
    xmpp->running = 0;
    xmpp->connection = NULL;
    xmpp->fd = 0;
    xmpp->kqueue = 0;
    xmpp->enablepoll = 0;
    
}

void XmppSetStartupPresence(Xmpp *xmpp, int num, const char *show, const char *status) {
    free(xmpp->startup_presence_show);
    free(xmpp->startup_presence_status);
    xmpp->startup_presence_show = show ? strdup(show) : NULL;
    xmpp->startup_presence_status = status ? strdup(status) : NULL;
    xmpp->startup_presence_num = num;
}

static int iq_cb(xmpp_conn_t *conn, xmpp_stanza_t *stanza, void *userdata) {
    xmpp_stanza_t *disco = xmpp_stanza_get_child_by_name_and_ns(stanza, "query", "http://jabber.org/protocol/disco#info");
    //if(disco) {
    //    printf("disco\n");
    //}
    
    return 1;
}

typedef struct StrBuf {
    char *str;
    size_t alloc;
    size_t length;
} StrBuf;

static void strbuf_append(StrBuf *buf, const char *str, size_t len) {
    if(buf->length + len > buf->alloc) {
        buf->alloc += len + 256;
        buf->str = realloc(buf->str, buf->alloc);
    }
    
    memcpy(buf->str + buf->length, str, len);
    buf->length += len;
}

static char* html_stanza2text(xmpp_ctx_t *ctx, xmpp_stanza_t *html) {
    StrBuf buf;
    buf.alloc = 512;
    buf.length = 0;
    buf.str = malloc(buf.alloc);
    
    xmpp_stanza_t *children = xmpp_stanza_get_children(html);
    while(children) {
        char *text = NULL;
        size_t textlen = 0;
        xmpp_stanza_to_text(children, &text, &textlen);
        if(textlen > 0) {
            strbuf_append(&buf, text, textlen);
        }
        xmpp_free(ctx, text);
        
        children = xmpp_stanza_get_next(children);
    }
    
    strbuf_append(&buf, "\0", 1);
    return buf.str;
}

/*
 * xmpp message handler
 */
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
        // usually messages should contain a body
        // other messages (that are currently implemented here) are
        // chat state messages
        xmpp_stanza_t *children = xmpp_stanza_get_children(stanza);
        while(children) {
            const char *ns = xmpp_stanza_get_ns(children);
            const char *name = xmpp_stanza_get_name(children);
            if(!strcmp(ns, "http://jabber.org/protocol/chatstates")) {
                // chat status updates
                if(!strcmp(name, "composing")) {
                    app_chatstate(xmpp, from, XMPP_CHATSTATE_COMPOSING);
                } else if(!strcmp(name, "paused")) {
                    app_chatstate(xmpp, from, XMPP_CHATSTATE_PAUSED);
                } else if(!strcmp(name, "active")) {
                    app_chatstate(xmpp, from, XMPP_CHATSTATE_ACTIVE);
                } else if(!strcmp(name, "inactive")) {
                    app_chatstate(xmpp, from, XMPP_CHATSTATE_INACTIVE);
                } else if(!strcmp(name, "gone")) {
                    app_chatstate(xmpp, from, XMPP_CHATSTATE_GONE);
                }
            }
            
            children = xmpp_stanza_get_next(children);
        }
        
        return 1;
    }
    
    xmpp_stanza_t *html = xmpp_stanza_get_child_by_name(stanza, "html");
    char *html_text = NULL;
    if(html) {
        xmpp_stanza_t *html_body = xmpp_stanza_get_child_by_name(html, "body");
        if(html_body) {
            html_text = html_stanza2text(xmpp->ctx, html_body);
        }
    }
    
    char *body_text = xmpp_stanza_get_text(body);
    //printf("message_cb: msg from %s: %s\n", from, body_text);
    
    if(body_text) {
        size_t len = strlen(body_text);
        char *decrypt_msg = NULL;
        char *user_msg = body_text;
        bool secure = false;
        
        // check for otr messages
        if(len > 4 && !memcmp(body_text, "?OTR", 4)) {
            int otr_err;
            decrypt_msg = decrypt_message(xmpp, from, body_text, &otr_err);
            user_msg = decrypt_msg;
            secure = true;
            
            if(otr_err == 1) {
                // this message could be part of an otr handshake
                printf("internal otr message\n");
                // check conversation encryption status
                ConnContext *root = xmpp->userstate->context_root;
                ConnContext *child = root->recent_rcvd_child;
                
                if(child && child->username && !strcmp(child->username, from)) {
                    if(child->msgstate == OTRL_MSGSTATE_FINISHED) {
                        app_update_secure_status(xmpp, from, false);
                    }
                }
            }
        } else if(html_text) {
            user_msg = html_text;
        }
        
        // send the mssage to the app thread
        if(user_msg) {
            app_message(xmpp, from, user_msg, secure);
        }
        
        if(decrypt_msg) {
            free(decrypt_msg);
        }
    }
    
    free(body_text);
    free(html_text);
    
    return 1;
}

/*
 * callback function for roster queries
 */
static int query_roster_cb(xmpp_conn_t *conn, xmpp_stanza_t *stanza, void *userdata) {
    XmppQuery *xquery = userdata;
    
    const char *type = xmpp_stanza_get_type(stanza);
    if(!strcmp(type, "error")) {
        fprintf(stderr, "query %s failed", xquery->id);
    } else {
        xmpp_stanza_t *query = xmpp_stanza_get_child_by_name(stanza, "query");
        
        size_t contactsAlloc = 32;
        size_t contactsNum = 0;
        XmppContact *contacts = calloc(contactsAlloc, sizeof(XmppContact));
        
        // TODO: the contacts list should be updated in the app thread
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
    
    const char *ns = xmpp_stanza_get_ns(stanza);
    
    const char *type = xmpp_stanza_get_attribute(stanza, "type");
    const char *from = xmpp_stanza_get_attribute(stanza, "from");
    
    char *show = NULL;
    char *status = NULL;
    xmpp_stanza_t *show_elm = xmpp_stanza_get_child_by_name(stanza, "show");
    xmpp_stanza_t *status_elm = xmpp_stanza_get_child_by_name(stanza, "status");
    
    if(show_elm) {
        show = xmpp_stanza_get_text(show_elm);
    }
    if(status_elm) {
        status = xmpp_stanza_get_text(status_elm);
    }
    
    if(type && !strcmp(type, "subscribe")) {
        app_handle_presence_subscribe(xmpp, from);
    } else {
        app_handle_presence(xmpp, from, type, show, status);
    }
    
    free(show);
    free(status);
    
    return 1;
}

static void query_conatcts(Xmpp *xmpp, XmppQuery *xquery) {
    xmpp_stanza_t *iq = xmpp_iq_new(xmpp->ctx, "get", xquery->id);
    xmpp_stanza_t *query = xmpp_stanza_new(xmpp->ctx);
    xmpp_stanza_set_name(query, "query");
    xmpp_stanza_set_ns(query, XMPP_NS_ROSTER);
    xmpp_stanza_add_child(iq, query);


    xmpp_id_handler_add(xmpp->connection, query_roster_cb, xquery->id, xquery);
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
        xmpp_handler_add(conn, iq_cb, NULL, "iq", NULL, xmpp);
        xmpp_handler_add(conn, message_cb, NULL, "message", NULL, xmpp);
        xmpp_handler_add(conn, presence_cb, NULL, "presence", NULL, xmpp);
        
        // send startup presence message
        Xmpp_Send_Presence(xmpp, xmpp->startup_presence_show, xmpp->startup_presence_status, xmpp->startup_presence_priority);
        
        // get contacts
        XmppQueryContacts(xmpp);
        
        // set app status
        app_set_status(xmpp, xmpp->startup_presence_num > 0 ? xmpp->startup_presence_num : XMPP_STATUS_ONLINE);
    } else {
        app_set_status(xmpp, XMPP_STATUS_OFFLINE);
        
    }
    
    xmpp->enablepoll = 1;
}

int socketopt_cb(xmpp_conn_t *conn, void *sock) {
    // we need the socket to use our own polling
    im_account->fd = *((int*)sock);
    
    //int val = 1;
    //setsockopt(im_account->fd, SOL_SOCKET, SO_KEEPALIVE, &val, sizeof(val));
    
    xmpp_sockopt_cb_keepalive(conn, sock);
    
    return 0;
}

static int session_xmpp_connect(Xmpp *xmpp) {
    xmpp_conn_t *connection = xmpp->connection;
    connection = xmpp_conn_new(xmpp->ctx);
    xmpp_conn_set_flags(connection, xmpp->settings.flags);
    
    // TODO: replace im_account with threadsafe list, when multi account is implemented
    im_account = xmpp;
    
    xmpp_conn_set_sockopt_callback(connection, socketopt_cb);
    
    xmpp_conn_set_jid(connection, xmpp->xid);
    xmpp_conn_set_pass(connection, xmpp->settings.password);

    char *host = xmpp->settings.host;
    unsigned short port = xmpp->settings.port;
    if(host && strlen(host) == 0) {
        host = NULL;
    }
    
    if(xmpp_connect_client(connection, host, port, connect_cb, xmpp) != XMPP_EOK) {
        xmpp_conn_release(connection);
        return 1;
    }
    
    xmpp->connection = connection;
    
    return 0;
}


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
            app_set_status(xmpp, 0);
            break;
        }
        
        if(xmpp->enablepoll) {
            int queuelen = xmpp_conn_send_queue_len(xmpp->connection);
            if(queuelen == 0) {
                struct timespec timeout;
                timeout.tv_nsec = 0;
                timeout.tv_sec = 30;
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

/*
 * start the xmpp thread and connect to the server
 */
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
    close(xmpp->fd);
    xmpp_stop(xmpp->ctx);
    xmpp->running = 0;
    xmpp->fd = -1;
    
    close(xmpp->kqueue);
}


void XmppStop(Xmpp *xmpp) {
    XmppCall(xmpp, xmpp_stop_cb, NULL);
}

void XmppCall(Xmpp *xmpp, xmpp_callback_func cb, void *userdata) {
    XmppEvent *ev = malloc(sizeof(XmppEvent));
    ev->callback = cb;
    ev->userdata = userdata;
    
    struct kevent kev;
    EV_SET(&kev, (uintptr_t)ev, EVFILT_USER, EV_ADD|EV_ONESHOT, NOTE_TRIGGER, 0, ev);
    kevent(xmpp->kqueue, &kev, 1, NULL, 0, NULL);
    
}

typedef struct {
    char *to;
    char *message;
    bool encrypt;
} xmpp_msg;


typedef struct {
    char *to;
    enum XmppChatstate state;
} xmpp_state_msg;

static const char* xmpp_state2str(enum XmppChatstate state) {
    switch(state) {
        case XMPP_CHATSTATE_ACTIVE: {
            return "active";
        }
        case XMPP_CHATSTATE_PAUSED: {
            return "paused";
        }
        case XMPP_CHATSTATE_COMPOSING: {
            return "composing";
        }
        case XMPP_CHATSTATE_GONE: {
            return "gone";
        }
        case XMPP_CHATSTATE_INACTIVE: {
            return "inactive";
        }
    }
    return NULL;
}

void Xmpp_Send_State(Xmpp *xmpp, const char *to, enum XmppChatstate s) {
    char idbuf[16];
    snprintf(idbuf, 16, "%d", ++xmpp->iq_id);
    xmpp_stanza_t *chatmsg = xmpp_message_new(xmpp->ctx, "chat", to, idbuf);
    xmpp_stanza_t *state = xmpp_stanza_new(xmpp->ctx);
    const char *state_str = xmpp_state2str(s);
    if(state_str) {
        xmpp_stanza_set_name(state, state_str);
        xmpp_stanza_set_ns(state, "http://jabber.org/protocol/chatstates");
        
        xmpp_stanza_add_child(chatmsg, state);
        
        xmpp_send(xmpp->connection, chatmsg);
        xmpp_stanza_release(chatmsg);
    }
}

static void send_xmpp_state_msg(Xmpp *xmpp, void *userdata) {
    xmpp_state_msg *msg = userdata;
    
    Xmpp_Send_State(xmpp, msg->to, msg->state);

    free(msg->to);
    free(msg);
}



void XmppStateMessage(Xmpp *xmpp, const char *to, enum XmppChatstate state) {
    xmpp_state_msg *msg = malloc(sizeof(xmpp_state_msg));
    msg->to = strdup(to);
    msg->state = state;
    XmppCall(xmpp, send_xmpp_state_msg, msg);
}

typedef struct {
    char *xid;
} xmpp_authorize_msg;

static void send_xmpp_authorize_msg(Xmpp *xmpp, void *userdata) {
    xmpp_authorize_msg *msg = userdata;
    
    xmpp_stanza_t *response = xmpp_stanza_new(xmpp->ctx);
    xmpp_stanza_set_name(response, "presence");
    xmpp_stanza_set_type(response, "subscribed");
    xmpp_stanza_set_attribute(response, "to", msg->xid);

    xmpp_send(xmpp->connection, response);
    xmpp_stanza_release(response);
    
    // refresh contact list
    XmppQueryContacts(xmpp);
    
    free(msg->xid);
    free(msg);
}

void XmppAuthorize(Xmpp *xmpp, const char *xid) {
    xmpp_authorize_msg *msg = malloc(sizeof(xmpp_authorize_msg));
    msg->xid = strdup(xid);
    XmppCall(xmpp, send_xmpp_authorize_msg, msg);
}


typedef struct {
    char *xid;
    bool unsub;
} xmpp_remove_msg;

static void send_xmpp_remove_msg(Xmpp *xmpp, void *userdata) {
    xmpp_remove_msg *msg = userdata;
    
    // remove XID from roster
    char idbuf[16];
    snprintf(idbuf, 16, "%d", ++xmpp->iq_id);
    
    xmpp_stanza_t *iq = xmpp_iq_new(xmpp->ctx, "set", idbuf);
    xmpp_stanza_t *query = xmpp_stanza_new(xmpp->ctx);
    xmpp_stanza_set_name(query, "query");
    xmpp_stanza_set_ns(query, XMPP_NS_ROSTER);
    xmpp_stanza_add_child(iq, query);
    
    xmpp_stanza_t *item = xmpp_stanza_new(xmpp->ctx);
    xmpp_stanza_set_name(item, "item");
    xmpp_stanza_set_attribute(item, "jid", msg->xid);
    xmpp_stanza_set_attribute(item, "subscription", "remove");
    xmpp_stanza_add_child(query, item);
    
    xmpp_send(xmpp->connection, iq);
    xmpp_stanza_release(iq);
    
    if(msg->unsub) {
        // unsubscribe presence
        xmpp_stanza_t *presence = xmpp_stanza_new(xmpp->ctx);
        xmpp_stanza_set_name(presence, "presence");
        xmpp_stanza_set_attribute(presence, "to", msg->xid);
        xmpp_stanza_set_attribute(presence, "type", "unsubscribe");

        xmpp_send(xmpp->connection, presence);
        xmpp_stanza_release(presence);
    }
    
    XmppQueryContacts(xmpp);
    
    free(msg->xid);
    free(msg);
}

void XmppRemove(Xmpp *xmpp, const char *xid, bool unsub) {
    xmpp_remove_msg *msg = malloc(sizeof(xmpp_remove_msg));
    msg->xid = strdup(xid);
    msg->unsub = unsub;
    XmppCall(xmpp, send_xmpp_remove_msg, msg);
}

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
        Xmpp_Send_State(xmpp, msg->to, XMPP_CHATSTATE_ACTIVE);
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

typedef struct {
    char *show;
    char *status;
    int priority;
} xmpp_presence_msg;



void Xmpp_Send_Presence(Xmpp *xmpp, const char *show, const char *status, int priority) {
    xmpp_stanza_t *presence = xmpp_presence_new(xmpp->ctx);
    if(show) {
        xmpp_stanza_t *show_elm = xmpp_stanza_new(xmpp->ctx);
        xmpp_stanza_set_name(show_elm, "show");
        xmpp_stanza_t *show_text = xmpp_stanza_new(xmpp->ctx);
        xmpp_stanza_set_text(show_text, show);
        xmpp_stanza_add_child(show_elm, show_text);
        xmpp_stanza_add_child(presence, show_elm);
    }
    if(status) {
        xmpp_stanza_t *status_elm = xmpp_stanza_new(xmpp->ctx);
        xmpp_stanza_set_name(status_elm, "status");
        xmpp_stanza_t *status_text = xmpp_stanza_new(xmpp->ctx);
        xmpp_stanza_set_text(status_text, status);
        xmpp_stanza_add_child(status_elm, status_text);
        xmpp_stanza_add_child(presence, status_elm);
    }
    if(priority > 0) {
        xmpp_stanza_t *priority_elm = xmpp_stanza_new(xmpp->ctx);
        xmpp_stanza_set_name(priority_elm, "priority");
        char buf[32];
        snprintf(buf, 32, "%d", priority);
        xmpp_stanza_t *priority_text = xmpp_stanza_new(xmpp->ctx);
        xmpp_stanza_set_text(priority_text, buf);
        xmpp_stanza_add_child(priority_elm, priority_text);
        xmpp_stanza_add_child(presence, priority_elm);
    }
    
    xmpp_send(xmpp->connection, presence);
    xmpp_stanza_release(presence);
}

static void xmpp_send_presence(Xmpp *xmpp, void *userdata) {
    xmpp_presence_msg *msg = userdata;
    
    Xmpp_Send_Presence(xmpp, msg->show, msg->status, msg->priority);
    
    free(msg->status);
    free(msg->show);
    free(msg);
}

void XmppPresence(Xmpp *xmpp, const char *show, const char *status, int priority) {
    xmpp_presence_msg *presence = malloc(sizeof(xmpp_presence_msg));
    presence->show = show ? strdup(show) : NULL;
    presence->status = status ? strdup(status) : NULL;
    presence->priority = priority;
    XmppCall(xmpp, xmpp_send_presence, presence);
}

typedef struct {
    char *xid;
    char *name;
} xmpp_subscription_msg;

static void xmpp_add_contact(Xmpp *xmpp, void *userdata) {
    xmpp_subscription_msg *msg = userdata;
    
    // add XID to roster
    char idbuf[16];
    snprintf(idbuf, 16, "%d", ++xmpp->iq_id);
    
    xmpp_stanza_t *iq = xmpp_iq_new(xmpp->ctx, "set", idbuf);
    xmpp_stanza_t *query = xmpp_stanza_new(xmpp->ctx);
    xmpp_stanza_set_name(query, "query");
    xmpp_stanza_set_ns(query, XMPP_NS_ROSTER);
    xmpp_stanza_add_child(iq, query);
    
    xmpp_stanza_t *item = xmpp_stanza_new(xmpp->ctx);
    xmpp_stanza_set_name(item, "item");
    xmpp_stanza_set_attribute(item, "jid", msg->xid);
    if(msg->name) {
        xmpp_stanza_set_attribute(item, "name", msg->name);
    }
    xmpp_stanza_add_child(query, item);
    
    xmpp_send(xmpp->connection, iq);
    xmpp_stanza_release(iq);
    
    // subscribe
    xmpp_stanza_t *presence = xmpp_stanza_new(xmpp->ctx);
    xmpp_stanza_set_name(presence, "presence");
    xmpp_stanza_set_type(presence, "subscribe");
    xmpp_stanza_set_attribute(presence, "to", msg->xid);
    
    xmpp_send(xmpp->connection, presence);
    xmpp_stanza_release(presence);
    
    free(msg->xid);
    free(msg);
    
    // refresh contact list
    XmppQueryContacts(xmpp);
}

void XmppAddContact(Xmpp *xmpp, const char *xid) {
    xmpp_subscription_msg *msg = malloc(sizeof(xmpp_subscription_msg));
    msg->xid = strdup(xid);
    msg->name = NULL;
    XmppCall(xmpp, xmpp_add_contact, msg);
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


XmppSession* XmppGetSession(Xmpp *xmpp, const char *recipient) {
    char *xid = strdup(recipient);
    char *res = strchr(xid, '/');
    if(res) {
        char *resource = strdup(res);
        *res = 0;
        res = resource;
    }
    
    // Is the conversation already open?
    // This could potentially optimized with an sorted array if it is necessary
    XmppConversation *conv = NULL;
    for(int i=0;i<xmpp->nconversations;i++) {
        if(!strcmp(xmpp->conversations[i]->xid, xid)) {
            conv = xmpp->conversations[i];
            break;
        }
    }
    
    // If no conversation is found, create a new conversation and add it to the array
    if(!conv) {
        if(xmpp->nconversations >= xmpp->conversationsalloc) {
            xmpp->conversationsalloc += 8;
            xmpp->conversations = realloc(xmpp->conversations, sizeof(XmppConversation*) * xmpp->conversationsalloc);
        }
        
        conv = malloc(sizeof(XmppConversation));
        memset(conv, 0, sizeof(XmppConversation));
        xmpp->conversations[xmpp->nconversations++] = conv;
        
        conv->xid = xid;
        xid = NULL; // disable free(xid)
    }
    
    // Add recipient to the conversation if not present
    XmppSession *session = NULL;
    if(res) {
        for(int i=0;i<conv->nsessions;i++) {
            if(!strcmp(conv->sessions[i]->resource, res)) {
                session = conv->sessions[i];
                break;
            }
        }
    } else {
        if(conv->nores) {
            session = conv->nores;
        } else {
            session = malloc(sizeof(XmppSession));
            memset(session, 0, sizeof(XmppSession));
            session->conversation = conv;
            conv->nores = session;
        }
    }
    
    if(!session) {
        if(conv->nsessions >= conv->snalloc) {
            conv->snalloc += 4;
            conv->sessions = realloc(conv->sessions, sizeof(XmppSession*) * conv->nsessions);
        }
        
        session = malloc(sizeof(XmppSession));
        memset(session, 0, sizeof(XmppSession));
        conv->sessions[conv->nsessions++] = session;
        
        session->resource = res;
        session->conversation = conv;
        res = NULL; // disable free(res)
    } 
    
    
    if(xid) {
        free(xid);
    }
    if(res) {
        free(res);
    }
    return session;
}

void XmppSessionRemoveAndDestroy(XmppSession *sn) {
    if(sn->conversation) {
        // find sn in the session array
        XmppConversation *conv = sn->conversation;
        int snindex = -1;
        for(int i=0;i<conv->nsessions;i++) {
            if(conv->sessions[i] == sn) {
                snindex = i;
                break;
            }
        }
        // remove the session from the array
        if(snindex >= 0) {
            if(snindex+1 < conv->nsessions) {
                memmove(conv->sessions+snindex, conv->sessions+snindex+1, conv->nsessions - snindex + 1);
            }
            conv->nsessions--;
        } else if(conv->nores == sn) {
            conv->nores = NULL;
        }
    }
    
    if(sn->resource) {
        free(sn->resource);
    }
    free(sn);
}
