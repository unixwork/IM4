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


#ifndef otr_h
#define otr_h

#include <libotr/proto.h>
#include <libotr/userstate.h>
#include <libotr/message.h>
#include <libotr/privkey.h>

#include "xmpp.h"

/*
 * starts the otr session with recipient
 */
void start_otr(Xmpp *xmpp, const char *recipient);

/*
 * terminate the otr session
 */
void stop_otr(Xmpp *xmpp, const char *recipient);

char *encrypt_message(Xmpp *xmpp, const char *to, const char *message, int *error);
char *decrypt_message(Xmpp *xmpp, const char *from, const char *message, int *error);

// OTR AppOps Functions

OtrlPolicy otr_policy(void *opdata, ConnContext *context);
void otr_create_privkey(void *opdata, const char *accountname,
    const char *protocol);
int otr_is_logged_in(void *opdata, const char *accountname,
    const char *protocol, const char *recipient);
void otr_inject_message(void *opdata, const char *accountname,
    const char *protocol, const char *recipient, const char *message);
void otr_update_context_list(void *opdata);
void otr_new_fingerprint(void *opdata, OtrlUserState us,
    const char *accountname, const char *protocol,
    const char *username, unsigned char fingerprint[20]);
void otr_write_fingerprints(void *opdata);
void otr_gone_secure(void *opdata, ConnContext *context);
void otr_gone_insecure(void *opdata, ConnContext *context);
void otr_still_secure(void *opdata, ConnContext *context, int is_reply);
int otr_max_message_size(void *opdata, ConnContext *context);
const char * otr_account_name(void *opdata, const char *account,
    const char *protocol);
void otr_account_name_free(void *opdata, const char *account_name);
void otr_received_symkey(void *opdata, ConnContext *context,
    unsigned int use, const unsigned char *usedata,
    size_t usedatalen, const unsigned char *symkey);
const char * otr_error_message(void *opdata, ConnContext *context, OtrlErrorCode err_code);
void otr_otr_error_message_free(void *opdata, const char *err_msg);
const char * otr_resent_msg_prefix(void *opdata, ConnContext *context);
void otr_resent_msg_prefix_free(void *opdata, const char *prefix);
void otr_handle_smp_event(void *opdata, OtrlSMPEvent smp_event,
    ConnContext *context, unsigned short progress_percent,
    char *question);
void otr_handle_msg_event(void *opdata, OtrlMessageEvent msg_event,
    ConnContext *context, const char *message,
    gcry_error_t err);
void otr_create_instag(void *opdata, const char *accountname,
    const char *protocol);
void otr_convert_msg(void *opdata, ConnContext *context,
    OtrlConvertType convert_type, char ** dest, const char *src);
void otr_convert_free(void *opdata, ConnContext *context, char *dest);
void otr_timer_control(void *opdata, unsigned int interval);

#endif /* otr_h */
