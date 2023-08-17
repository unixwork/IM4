//
//  otr.h
//  IM4
//
//  Created by Olaf Wintermann on 16.08.23.
//

#ifndef otr_h
#define otr_h

#include <libotr/proto.h>
#include <libotr/userstate.h>
#include <libotr/message.h>
#include <libotr/privkey.h>

#include "xmpp.h"

void start_otr(Xmpp *xmpp, const char *recipient);

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
