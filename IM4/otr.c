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


#include "otr.h"

#include "app.h"

#define IM_PROTOCOL "xmpp"

static OtrlMessageAppOps otr_ops = {
    otr_policy,
    otr_create_privkey,
    otr_is_logged_in,
    otr_inject_message,
    otr_update_context_list,
    otr_new_fingerprint,
    otr_write_fingerprints,
    otr_gone_secure,
    otr_gone_insecure,
    otr_still_secure,
    otr_max_message_size,
    otr_account_name,
    otr_account_name_free,
    otr_received_symkey,
    otr_error_message,
    otr_otr_error_message_free,
    otr_resent_msg_prefix,
    otr_resent_msg_prefix_free,
    otr_handle_smp_event,
    otr_handle_msg_event,
    otr_create_instag,
    otr_convert_msg,
    otr_convert_free,
    otr_timer_control
};



void start_otr(Xmpp *xmpp, const char *recipient) {
    char *msg_crypt;
    otrl_message_sending(
            xmpp->userstate,
            &otr_ops,
            xmpp,
            xmpp->settings.jid,
            IM_PROTOCOL,
            recipient,
            OTRL_INSTAG_BEST,
            "?OTR?",
            NULL,
            &msg_crypt,
            OTRL_FRAGMENT_SEND_SKIP,
            NULL,
            NULL,
            NULL);
    Xmpp_Send(xmpp, recipient, msg_crypt);
    free(msg_crypt);
}

void stop_otr(Xmpp *xmpp, const char *recipient) {
    // this seems to work, however we don't get the gone_insecure message
    otrl_message_disconnect(
            xmpp->userstate,
            &otr_ops,
            xmpp,
            xmpp->settings.jid,
            IM_PROTOCOL,
            recipient,
            OTRL_INSTAG_BEST);
}

char *encrypt_message(Xmpp *xmpp, const char *to, const char *message, int *error) {
    char *enctext = NULL;
    int err = otrl_message_sending(
            xmpp->userstate,
            &otr_ops,
            xmpp,
            xmpp->settings.jid,
            IM_PROTOCOL,
            to,
            OTRL_INSTAG_BEST,
            message,
            NULL,
            &enctext,
            OTRL_FRAGMENT_SEND_SKIP,
            NULL,
            NULL,
            NULL);
    *error = err;
    
    return enctext;
}

char *decrypt_message(Xmpp *xmpp, const char *from, const char *message, int *error) {
    char *msg_decrypt = NULL;
    int err = otrl_message_receiving(xmpp->userstate,
                                     &otr_ops,
                                     xmpp,
                                     xmpp->settings.jid,
                                     IM_PROTOCOL,
                                     from,
                                     message,
                                     &msg_decrypt,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL);
    *error = err;
    return msg_decrypt;
}


// OTR AppOps Functions

OtrlPolicy otr_policy(void *opdata, ConnContext *context) {
    return OTRL_POLICY_ALLOW_V3;
}

void otr_create_privkey(void *opdata, const char *accountname,
    const char *protocol)
{
    Xmpp *xmpp = opdata;
    
    char *filename = app_configfile("otr.private_key");
    
    XmppLog("otr: create private key\n");
    
    char *buf = NULL;
    asprintf(&buf, "account = %s\nfilename = %s\n", accountname, filename);
    XmppLog(buf);
    free(buf);
    
    free(filename);
}

int otr_is_logged_in(void *opdata, const char *accountname,
    const char *protocol, const char *recipient)
{
    return 1;
}

void otr_inject_message(void *opdata, const char *accountname,
    const char *protocol, const char *recipient, const char *message)
{
    Xmpp *xmpp = opdata;
    Xmpp_Send(xmpp, recipient, message);
}

void otr_update_context_list(void *opdata) {
    
}

void otr_new_fingerprint(void *opdata, OtrlUserState us,
    const char *accountname, const char *protocol,
    const char *username, unsigned char fingerprint[20])
{
    Xmpp *xmpp = opdata;
    app_handle_new_fingerprint(xmpp, username, fingerprint, 20);
}

void otr_write_fingerprints(void *opdata) {
    Xmpp *xmpp = opdata;
    char *filename = app_configfile("otr.fingerprints");
    otrl_privkey_write_fingerprints(xmpp->userstate, filename);
}

void otr_gone_secure(void *opdata, ConnContext *context) {
    printf("gone secure\n");
    Xmpp *xmpp = opdata;
    app_update_secure_status(xmpp, context->username, true);
}

void otr_gone_insecure(void *opdata, ConnContext *context) {
    printf("gone insecure\n");
    Xmpp *xmpp = opdata;
    app_update_secure_status(xmpp, context->username, false);
}

void otr_still_secure(void *opdata, ConnContext *context, int is_reply) {
    printf("still secure\n");
    Xmpp *xmpp = opdata;
    app_update_secure_status(xmpp, context->username, true);
}

int otr_max_message_size(void *opdata, ConnContext *context) {
    return 1024*1024;
}

const char * otr_account_name(void *opdata, const char *account,
    const char *protocol)
{
    Xmpp *xmpp = opdata;
    return xmpp->settings.jid;
}

void otr_account_name_free(void *opdata, const char *account_name) {
    // TODO
}

void otr_received_symkey(void *opdata, ConnContext *context,
    unsigned int use, const unsigned char *usedata,
    size_t usedatalen, const unsigned char *symkey)
{
    
}

const char * otr_error_message(void *opdata, ConnContext *context,
    OtrlErrorCode err_code)
{
    return "";
}

void otr_otr_error_message_free(void *opdata, const char *err_msg) {
    
}

const char * otr_resent_msg_prefix(void *opdata, ConnContext *context) {
    return "";
}

void otr_resent_msg_prefix_free(void *opdata, const char *prefix) {
    
}

void otr_handle_smp_event(void *opdata, OtrlSMPEvent smp_event,
    ConnContext *context, unsigned short progress_percent,
    char *question)
{
    // TODO
}

void otr_handle_msg_event(void *opdata, OtrlMessageEvent msg_event,
    ConnContext *context, const char *message,
    gcry_error_t err)
{
    app_otr_error(opdata, context->username, msg_event);
}

void otr_create_instag(void *opdata, const char *accountname,
    const char *protocol)
{
    Xmpp *xmpp = opdata;
    
    char *basepath = app_configfile("");
    
    char *filename;
    asprintf(&filename, "%s/instag_%s.txt", basepath, accountname);
    otrl_instag_generate(xmpp->userstate, filename, accountname, protocol);
    
    free(basepath);
    free(filename);
}

void otr_convert_msg(void *opdata, ConnContext *context,
    OtrlConvertType convert_type, char ** dest, const char *src)
{
    
}

void otr_convert_free(void *opdata, ConnContext *context, char *dest) {
    
}

void otr_timer_control(void *opdata, unsigned int interval) {
    
}
