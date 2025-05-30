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

#import <Cocoa/Cocoa.h>

#include "xmpp.h"

#import "IM4-Bridging-Header.h"
#import "IM4-Swift.h"

NS_ASSUME_NONNULL_BEGIN

@interface ConversationWindowController : NSWindowController<NSWindowDelegate, NSTextViewDelegate>

@property (readonly) UITemplate *tpl;
@property (readonly) Xmpp *xmpp;
@property (readonly) XmppConversation *conversation;
@property (readonly) Boolean secure;
@property (copy) NSString* xid;
@property (copy) NSString* alias;
@property bool online;
@property bool loading;
@property bool composing;
@property int unread;
@property NSMutableAttributedString* chatstateMsg;
@property bool selectSingleSession;
@property bool selectXidSession;
@property (readonly) NSMenuItem *singleSessionMenuItem;
@property (readonly) NSMenuItem *multiSessionMenuItem;
@property (copy) NSURL *historyFile;

- (id)initConversation:(NSString*)xid alias:(NSString*)alias xmpp:(Xmpp*)xmpp;

- (void)updateStatus;

- (BOOL)selectConversation:(NSMenuItem*)sender;
- (BOOL)xidConversation:(NSMenuItem*)sender;
- (BOOL)singleSession:(NSMenuItem*)sender;
- (BOOL)multiSession:(NSMenuItem*)sender;

- (void)addStringToLog:(NSString*)str;
- (void)addAttributedStringToLog:(NSAttributedString*)str;

- (void)addLog:(NSString*)message incoming:(Boolean)incoming secure:(Boolean)secure;

- (void)sendMessage:(Boolean)force;

- (void)sendState:(enum XmppChatstate) state;

- (void)addReceivedMessage:(NSString*)msg resource:(NSString*)res secure:(BOOL)secure;

- (void)clearChatStateMsg;

- (void)chatState:(enum XmppChatstate)state;

- (void)otrError:(uint64_t)error from:(NSString*)from;

- (void)setSecure:(Boolean)secure resource:(nullable NSString*)res;

- (void)newFingerprint:(NSString*)fingerprint from:(NSString*)from;

- (void)updateFonts:(NSFont*)chatFont inputFont:(NSFont*)inputFont;

- (IBAction) secureAction:(id)sender;

- (IBAction)saveDocument:(id)sender;
- (IBAction)saveDocumentAs:(id)sender;

@end

NS_ASSUME_NONNULL_END
