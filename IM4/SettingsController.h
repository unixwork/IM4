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
#import "xmpp.h"

#import "IM4-Bridging-Header.h"
#import "IM4-Swift.h"

// Xcode debug builds have IM4_TEST=1 defined
#ifdef IM4_TEST
#define IM4_APPNAME "IM4TEST"
#else
#define IM4_APPNAME "IM4"
#endif

#define IM4_APPNAME_NS @ IM4_APPNAME

NS_ASSUME_NONNULL_BEGIN

@interface SettingsController : NSWindowController<NSWindowDelegate>

@property (readonly) Xmpp *xmpp;

@property (readonly) NSDictionary *config;
@property (readonly) NSDictionary *aliases;

@property (copy) NSString *fingerprint;
@property (readonly) UITemplate *templateSettings;
@property (readonly) NSMutableDictionary *templateSettingsDict;

@property (readonly) TemplateSettingsController *tplController;

@property int UnencryptedMessages;

@property int StartupPresence;
@property int PreviousPresenceStatus;
@property (strong) NSString *PreviousPresenceStatusMessage;

@property BOOL TextDefaultSubDash;
@property BOOL TextDefaultSubQuote;

@property (strong) NSFont *ChatFont;
@property (strong) NSFont *InputFont;

@property (strong) NSFont *TmpChatFont;
@property (strong) NSFont *TmpInputFont;

- (id)initSettings;

- (void)initInputFields;

- (void) createXmpp;

- (void) recreateXmpp;

- (NSString*) configFilePath: (NSString*)fileName;

- (void) setAlias: (NSString*)alias forXid:(NSString*)xid;

- (NSString*) getAlias: (NSString*)xid;

- (BOOL) storeSettings;

- (void) createFingerprintFromPubkey;

- (void) changeFont:(nullable NSFontManager*)fontManager;
- (void) openFontPanel:(NSFont*)font;

- (IBAction)okAction:(id)sender;

- (IBAction)cancelAction:(id)sender;

- (IBAction)otrGenKey:(id)sender;

- (IBAction)logLevelSelected:(id)sender;

- (IBAction)openTemplateSettings:(id)sender;

- (IBAction)selectChatFont:(id)sender;

- (IBAction)selectMessageInputfont:(id)sender;



@end

NS_ASSUME_NONNULL_END
