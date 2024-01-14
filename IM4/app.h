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


#ifndef IM4_app_h
#define IM4_app_h

#include <stdbool.h>

#include "xmpp.h"

typedef void(*app_func)(void*);

char* app_configfile(const char *name);

void app_call_mainthread(app_func func, void *userdata);

void app_refresh_contactlist(void *xmpp);

void app_set_status(Xmpp *xmpp, int status);

void app_handle_presence(Xmpp *xmpp, const char *from, const char *status);

void app_handle_new_fingerprint(Xmpp *xmpp, const char *from, const unsigned char *fingerprint, size_t fplen);

void app_otr_error(Xmpp *xmpp, const char *from, uint64_t error);

void app_message(Xmpp *xmpp, const char *from, const char *msg_body);

void app_chatstate(Xmpp *xmpp, const char *from, enum XmppChatstate state);

void app_update_secure_status(Xmpp *xmpp, const char *from, bool issecure);

void app_add_log(const char *msg, size_t len);


#endif /* IM4_app_h */
