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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#import "AppDelegate.h"
#import "ConversationWindowController.h"
#import "SettingsController.h"
#import "LogWindowController.h"

#import "IM4-Bridging-Header.h"
#import "IM4-Swift.h"

#define IM4_DEFAULT_PRESENCE -1

static const char * presencenum2str(int num) {
    switch(num) {
        case XMPP_STATUS_OFFLINE: {
            return NULL;
        }
        case XMPP_STATUS_ONLINE: {
            return NULL;
        }
        case XMPP_STATUS_AWAY: {
            return "away";
        }
        case XMPP_STATUS_CHAT: {
            return "chat";
        }
        case XMPP_STATUS_DND: {
            return "dnd";
        }
        case XMPP_STATUS_XA: {
            return "xa";
        }
    }
    return NULL;
}

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSMenu *contactsContextMenu;
@property (strong) IBOutlet NSWindow *passwordDialog;
@property (strong) IBOutlet NSWindow *openConversationDialog;
@property (strong) IBOutlet NSWindow *statusMessageDialog;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _conversations = [[NSMutableDictionary alloc]init];
    _unread = 0;
    
    //_outlineViewController = [[OutlineViewController alloc]init];
    //[_contactList setDataSource:_outlineViewController];
    [_contactList setDelegate:_outlineViewController];
    
    
    _presence = [[NSMutableDictionary alloc]init];
    
    // config
    _settingsController = [[SettingsController alloc]initSettings];
    _logWindowController = [[LogWindowController alloc] initLogWindow];
    
    [self startXmpp];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *frameArray = [userDefaults objectForKey:@"ContactsWindowFrame"];
    if(frameArray && frameArray.count == 4) {
        NSNumber *width = [frameArray objectAtIndex:0];
        NSNumber *height = [frameArray objectAtIndex:1];
        NSNumber *x = [frameArray objectAtIndex:2];
        NSNumber *y = [frameArray objectAtIndex:3];
        NSRect frame;
        frame.size.width = width.doubleValue;
        frame.size.height = height.doubleValue;
        frame.origin.x = x.doubleValue;
        frame.origin.y = y.doubleValue;
        [_window setFrame:frame display:YES];
    }
    
    self.isOnline = NO;
    
    _originalSetStatusItemLabel = _setStatusItem.title;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [_settingsController storeSettings];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSRect frame = _window.frame;
    NSArray *array = @[
        [NSNumber numberWithDouble:frame.size.width],
        [NSNumber numberWithDouble:frame.size.height],
        [NSNumber numberWithDouble:frame.origin.x],
        [NSNumber numberWithDouble:frame.origin.y]
    ];
    [userDefaults setObject:array forKey:@"ContactsWindowFrame"];
    [userDefaults synchronize];
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag{
    if(!flag) {
        [_window setIsVisible:YES];
    }
    return YES;
}

- (ConversationWindowController*) conversationController:(XmppSession*)session {
    NSString *xid = [[NSString alloc] initWithUTF8String:session->conversation->xid];
    NSString *alias = [_settingsController getAlias:xid];
    if(!alias) {
        alias = xid;
    }
    
    ConversationWindowController *conversation = (__bridge ConversationWindowController*)session->conversation->userdata1;
    if(!conversation) {
        conversation = [[ConversationWindowController alloc]initConversation:xid alias:alias xmpp:_xmpp];
        [_conversations setObject:conversation forKey:xid];
        session->conversation->userdata1 = (__bridge void*)conversation;
        
        // add all online sessions
        Presence *presence = [self xidStatus:xid];
        for(NSString *res in presence.statusMap) {
            NSString *contact = [NSString stringWithFormat:@"%@%@", xid, res];
            (void)XmppGetSession(_xmpp, [contact UTF8String]); // adds a session, if it doesn't exist
        }
    }
    if(![conversation.window isVisible]) {
        [conversation showWindow:nil];
    }
    return conversation;
}

- (void) addUnread:(int)num {
    _unread += num;
    NSString *badge = nil;
    if(_unread != 0) {
        badge = [@(_unread) stringValue];
    }
    [[[NSApplication sharedApplication] dockTile] setBadgeLabel:badge];
}

- (void) setStatus:(int)status xmpp:(Xmpp*)xmpp updatePresence:(bool)updatePresence {
    // xmpp currently unused, because only one xmpp conn is supported
    
    _selectedStatus = status;
    _selectedStatusShowValue = NULL;
    
    // default presence values
    const char *presenceShow = NULL;
    const char *presenceStatus = NULL;
    int presencePriority = -1;
    
    // get values from the presence status dialog
    NSString *statusMsg = _statusMessageTextField.stringValue;
    if(statusMsg.length > 0) {
        presenceStatus = statusMsg.UTF8String;
    }
    
    NSString *titleIcon = @"";
    _isOnline = YES; // default value, only the offline status will change this
    switch(status) {
        case XMPP_STATUS_OFFLINE: {
            titleIcon = _settingsController.templateSettings.xmppPresenceIconOffline;
            
            [_presence removeAllObjects];
            [self refreshContactList];
            
            for(id key in _conversations) {
                ConversationWindowController *conv = [_conversations objectForKey:key];
                [conv updateStatus];
            }
            
            _isOnline = NO;
            updatePresence = NO;
            break;
        }
        case XMPP_STATUS_ONLINE: {
            titleIcon = _settingsController.templateSettings.xmppPresenceIconOnline;
            break;
        }
        case XMPP_STATUS_AWAY: {
            titleIcon = _settingsController.templateSettings.xmppPresenceIconAway;
            presenceShow = "away";
            break;
        }
        case XMPP_STATUS_CHAT: {
            titleIcon = _settingsController.templateSettings.xmppPresenceIconChat;
            presenceShow = "chat";
            break;
        }
        case XMPP_STATUS_DND: {
            titleIcon = _settingsController.templateSettings.xmppPresenceIconDnd;
            presenceShow = "dnd";
            break;
        }
        case XMPP_STATUS_XA: {
            titleIcon = _settingsController.templateSettings.xmppPresenceIconXA;
            presenceShow = "xa";
            break;
        }
    }
    // update presence dropdown menu
    [_statusButton selectItemAtIndex:status];
    
    // send presence status message
    if(updatePresence) {
        XmppPresence(_xmpp, presenceShow, presenceStatus, presencePriority);
    }
    _selectedStatusShowValue = presenceShow; // remember presence show value
    
    
    NSString *title = [[NSString alloc] initWithFormat:@"%@ IM4", titleIcon];
    [_window setTitle:title];
}

- (Presence*) xidStatus:(NSString*)xid {
    return [_presence valueForKey:xid];
}

- (NSString*) xidAlias:(NSString*)xid {
    NSString *alias = [_outlineViewController contactName:xid];
    return alias != nil ? alias : xid;
}

- (void) handleXmppMessage:(const char*)msg_body from:(const char*)from session:(XmppSession*)session secure:(BOOL)secure xmpp:(Xmpp*)xmpp {
    NSString *xid = [[NSString alloc] initWithUTF8String:session->conversation->xid];
    NSString *resource = [[NSString alloc] initWithUTF8String:session->resource];
    NSString *alias = [_settingsController getAlias:xid];
    NSString *message_text = [[NSString alloc]initWithUTF8String:msg_body];
    
    if(!alias) {
        alias = xid;
    }
    
    ConversationWindowController *conversation = [self conversationController:session];
    [conversation addReceivedMessage:message_text resource:resource secure:secure];
}

- (void) handlePresence:(const char*)from type:(const char*)type show:(const char*)show status:(const char*)status xmpp:(Xmpp*)xmpp {
    char *res = strchr(from, '/');
    size_t from_len;
    NSString *resource = @"";
    if(res) {
        from_len = res - from;
        resource = [[NSString alloc]initWithUTF8String:res];
    } else {
        from_len = strlen(from);
    }
    
    NSString *xid = [[NSString alloc]initWithBytes:from length:from_len encoding:NSUTF8StringEncoding];
    if(!type) {
        type = "";
    }
    NSString *t = [[NSString alloc]initWithUTF8String:type];
    NSString *s = status ? [[NSString alloc]initWithUTF8String:status] : nil;
    NSString *sh = show ? [[NSString alloc]initWithUTF8String:show] : nil;
    PresenceStatus *ps = [[PresenceStatus alloc]init:t status:s show:sh];
    
    // status msg
    bool new_session = NO;
    bool session_disconnected = NO;
    bool switch_to_session = NO;
    
    // _presence contains two nested NSMutableDictionary objects
    // The first dictionary from _presence uses the xid without the resource part as key
    // and contains a dictionary with the resource part as key and the status string as value.
    Presence *xid_status = [_presence valueForKey:xid];
    if(!strcmp(type, "unavailable")) {
        if(xid_status) {
            [xid_status.statusMap removeObjectForKey:resource];
        }
        ps = nil;
        session_disconnected = YES;
    } else {
        // if _presence doesn't contain an object for the xid, create a
        // mutable dictionary and add it
        if(xid_status == nil) {
            xid_status = [[Presence alloc]init];
            [_presence setObject:xid_status forKey:xid];
            new_session = YES;
        } else {
            if([xid_status presenceStatus:resource] == nil) {
                new_session = YES;
            }
        }
        // set the status for the resource
        [xid_status updateStatusFrom:resource status:ps];
    }
    
    if([_outlineViewController updateContact:xid updateStatus:true presence:ps unread:-1]) {
        [_contactList reloadData];
    }
    
    // add new session, if required
    XmppSession *sn = XmppGetSession(_xmpp, from);
    XmppConversation *conv = sn->conversation;
    
    bool manually_selected = FALSE;
    for(int i=0;i<conv->nsessions;i++) {
        if(conv->sessions[i]->manually_selected) {
            manually_selected = TRUE;
            break;
        }
    }
    
    
    if(!manually_selected) {
        // active session not manually selected, select this session as active
        // and all other sessions as inactive
        int snindex= -1;
        for(int i=0;i<conv->nsessions;i++) {
            conv->sessions[i]->enabled = FALSE; // first, disable all sessions
            if(conv->sessions[i] == sn) {
                snindex = i;
            }
        }
        
        // ps is nil when status is unavailable
        if(ps) {
            sn->enabled = TRUE; // enable the current session
            if(conv->nsessions > 1) {
                switch_to_session = YES;
            }
        } else {
            sn->enabled = FALSE;
            XmppSessionRemoveAndDestroy(sn);
        }
    }
    
    ConversationWindowController *conversation = [_conversations objectForKey:xid];
    if(conversation != nil) {
        [conversation updateStatus];
        
        // add presence msg to the chat log
        
        NSString *logMsg = nil;
        if(switch_to_session) {
            logMsg = [[NSString alloc] initWithFormat:@"xmpp: Session %@ selected\n", resource];
        } else if(new_session) {
            logMsg = [[NSString alloc] initWithFormat:@"xmpp: %@%@ connected\n", xid, resource];
        } else if(session_disconnected) {
            logMsg = [[NSString alloc] initWithFormat:@"xmpp: %@%@ disconnected\n", xid, resource];
        }
        
        if(logMsg) {
            [conversation addStringToLog:logMsg];
        }
    }
}

- (void) handleChatstate:(const char*)from state:(enum XmppChatstate)state session:(XmppSession*)session {
    char *res = strchr(from, '/');
    size_t from_len;
    NSString *resource = @"";
    if(res) {
        from_len = res - from;
        resource = [[NSString alloc]initWithUTF8String:res];
    } else {
        from_len = strlen(from);
    }
    
    NSString *xid = [[NSString alloc]initWithBytes:from length:from_len encoding:NSUTF8StringEncoding];
    ConversationWindowController *conversation = [_conversations objectForKey:xid];
    if(conversation != nil) {
        [conversation chatState:state];
    }
}

- (void) handleSecureStatus:(Boolean)status from:(const char*)from session:(XmppSession*)session xmpp:(Xmpp*)xmpp {
    ConversationWindowController *conversation = [self conversationController:session];
    NSString *resource = session->resource ? [[NSString alloc] initWithUTF8String:session->resource] : nil;
    [conversation setSecure:status resource:resource];
}

- (void) handleNewFingerprint:(unsigned char*)fingerprint length:(size_t)len from:(const char*)from session:(XmppSession*)session xmpp:(Xmpp*)xmpp {
    ConversationWindowController *conversation = [self conversationController:session];
    
    NSString *ns_from = [[NSString alloc]initWithUTF8String:from];
    
    size_t fpstr_len = len * 2 + len/4 + 1;
    char *fpstr = malloc(fpstr_len);
    char *fpstr_pos = fpstr;
    for(int i=0;i<len;i++) {
        int b = (i+1)%4;
        char *t = i > 0 && b == 0 ? " " : "";
        size_t w = snprintf(fpstr_pos, fpstr_len - (fpstr_pos - fpstr), "%x%s", (int)fingerprint[i], t);
        fpstr_pos += w;
    }
    NSString *ns_fingerprint = [[NSString alloc]initWithUTF8String: fpstr];
    free(fpstr);
    
    
    [conversation newFingerprint:ns_fingerprint from:ns_from];
}

- (void) handleOtrError:(uint64_t)error from:(const char*)from session:(XmppSession*)session xmpp:(Xmpp*)xmpp {
    NSString *nsfrom = [[NSString alloc]initWithUTF8String:from];
    
    ConversationWindowController *conversation = [self conversationController:session];
    [conversation otrError:error from:nsfrom];
}

- (void) refreshContactList {
    [_outlineViewController refreshContacts:_xmpp presence:_presence];
    [_contactList reloadData];
}

- (void) openConversation:(Contact*)contact {
    XmppSession *session = XmppGetSession(_xmpp, [contact.xid UTF8String]);
    
    ConversationWindowController *conversation = [self conversationController:session];
    [conversation showWindow:nil];
}

- (void) updateConversationAlias:(NSString*)xid newAlias:(NSString*)alias {
    ConversationWindowController *conversation = [_conversations objectForKey:xid];
    if(conversation) {
        conversation.alias = alias;
    }
}

- (void) startXmpp {
    if(_xmpp) {
        //XmppStop(_xmpp);
        [_outlineViewController clearContacts];
        [_contactList reloadData];
    }
    _xmpp = _settingsController.xmpp;
    if(_xmpp) {
        if(!_xmpp->settings.password || strlen(_xmpp->settings.password) == 0) {
            if(!_passwordDialog.isVisible) {
                NSString *loginPrompt = [[NSString alloc]initWithFormat:@"Enter password for %s", _xmpp->settings.jid ];
                _loginDialogXidLabel.stringValue = loginPrompt;
                [_passwordDialog makeKeyAndOrderFront:nil];
            }
            return;
        }
        
        if(_settingsController.StartupPresence > 0) {
            XmppSetStartupPresence(_xmpp, _settingsController.StartupPresence, presencenum2str(_settingsController.StartupPresence), NULL);
            XmppRun(_xmpp);
            self.isOnline = YES;
        }
    }
}

- (IBAction) menuPreferences:(id)sender {
    [_settingsController showWindow:nil];
}

- (IBAction) menuDebugLog:(id)sender {
    [_logWindowController showWindow:nil];
}

- (IBAction) menuContactList:(id)sender {
    [_window makeKeyAndOrderFront:self];
}

- (IBAction) statusSelected:(id)sender {
    const char *presenceStatus = NULL;
    
    // get values from the presence status dialog
    NSString *statusMsg = _statusMessageTextField.stringValue;
    if(statusMsg.length > 0) {
        presenceStatus = statusMsg.UTF8String;
    }
    
    int status = (int)[_statusButton selectedTag];
    
    if(status >= 0) {
        if(status == XMPP_STATUS_OFFLINE) {
            if(_xmpp) {
                XmppStop(_xmpp);
            }
            self.isOnline = NO;
        } else {
            if(self.isOnline) {
                [self setStatus:status xmpp:_xmpp updatePresence:true];
            } else {
                [_settingsController recreateXmpp];
                _xmpp = _settingsController.xmpp;
                if(_xmpp) {
                    XmppSetStartupPresence(_xmpp, status, presencenum2str(status), presenceStatus);
                    XmppRun(_xmpp);
                    self.isOnline = YES;
                } else {
                    [self setStatus:XMPP_STATUS_OFFLINE xmpp:_xmpp updatePresence:true];
                    return;
                }
            }
        }
        [self setStatus:status xmpp:_xmpp updatePresence:true];
    } else {
        [_statusButton selectItemAtIndex:self.selectedStatus];
        [_statusMessageDialog makeKeyAndOrderFront:nil];
    }
}


- (IBAction) loginCancel:(id)sender {
    _loginDialogPassword.stringValue = @"";
    _passwordDialog.isVisible = NO;
}

- (IBAction) loginOK:(id)sender {
    NSString *password = _loginDialogPassword.stringValue;
    if(password && password.length > 0) {
        free(_xmpp->settings.password);
        _xmpp->settings.password = strdup([password UTF8String]);
        [self startXmpp];
        _passwordDialog.isVisible = NO;
    }
}

- (IBAction) openConversationCancel:(id)sender {
    _openConversationDialog.isVisible = NO;
}

- (IBAction) openConversationOK:(id)sender {
    const char *recipient = [_openConversationXidTextField.stringValue UTF8String];
    int s = -1;
    int c = 0;
    size_t len = strlen(recipient);
    for(int i=0;i<len;i++) {
        if(recipient[i] == '@') {
            s = i;
            c++;
        }
    }
    if(s <= 0 || s+1 == len || c != 1) {
        _openConversationErrorField.stringValue = @"invalid XID";
        return;
    }
    
    
    XmppSession *session = XmppGetSession(_xmpp, recipient);
    if(session) {
        [self conversationController:session];
    }
    
    _openConversationDialog.isVisible = NO;
}

- (IBAction) statusDialogCancel:(id)sender {
    _statusMessageDialog.isVisible = NO;
}

- (IBAction) statusDialogOK:(id)sender {
    _statusMessageDialog.isVisible = NO;
    
    NSString *statusMsg = _statusMessageTextField.stringValue;
    const char *statusMsgStr = NULL;
    if(statusMsg.length > 0) {
        statusMsgStr = statusMsg.UTF8String;
        _setStatusItem.title = statusMsg;
    } else {
        _setStatusItem.title = _originalSetStatusItemLabel;
    }
    XmppPresence(_xmpp, _selectedStatusShowValue, statusMsgStr, IM4_DEFAULT_PRESENCE);
}

- (IBAction)newDocument:(id)sender {
    if(!_openConversationDialog.isVisible) {
        _openConversationXidTextField.stringValue = @"";
        _openConversationErrorField.stringValue = @"";
        [_openConversationDialog makeKeyAndOrderFront:nil];
    }
}

- (IBAction)add:(id)sender {
    printf("AppDelegate add\n");
}

@end
