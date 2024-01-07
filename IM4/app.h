//
//  app.h
//  IM4
//
//  Created by Olaf Wintermann on 12.08.23.
//


#ifndef IM4_app_h
#define IM4_app_h

#include <stdbool.h>



typedef void(*app_func)(void*);

char* app_configfile(const char *name);

void app_call_mainthread(app_func func, void *userdata);

void app_refresh_contactlist(void *xmpp);

void app_set_status(void *xmpp, int status);

void app_handle_presence(void *xmpp, const char *from, const char *status);

void app_handle_new_fingerprint(void *xmpp, const char *from, const unsigned char *fingerprint, size_t fplen);

void app_otr_error(void *xmpp, const char *from, uint64_t error);

void app_message(void *xmpp, const char *msg_body, const char *from);

void app_chatstate(void *xmpp, const char *from, enum XmppChatstate state);

void app_update_secure_status(void *xmpp, const char *from, bool issecure);

void app_add_log(const char *msg, size_t len);


#endif /* IM4_app_h */
