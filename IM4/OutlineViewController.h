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

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import "Contact.h"

#import "IM4-Bridging-Header.h"
#import "IM4-Swift.h"

#include "xmpp.h"

NS_ASSUME_NONNULL_BEGIN

@interface OutlineViewController : NSObject <NSOutlineViewDataSource, NSMenuDelegate, NSOutlineViewDelegate> {
    Boolean isEditing;
}

@property (readonly) UITemplate *tpl;

@property (copy) NSMutableArray *contacts;

@property (strong) IBOutlet NSOutlineView *outlineView;

- (void) refreshContacts:(Xmpp*)xmpp presence:(NSDictionary*)presence;

- (void) expandContact:(id)c;

- (void) clearContacts;

- (Contact*) contact:(NSString*)xid;

- (NSString*) contactName:(NSString*)xid;

- (Boolean) updateContact:(NSString*)xid updateStatus:(Boolean)updateStatus presence:(nullable PresenceStatus*)presence unread:(int)unread;

- (IBAction) doubleAction:(NSOutlineView*)sender;

- (IBAction) cellAction:(id)sender;

- (IBAction) renameMenuItem:(id)sender;
- (IBAction) removeMenuItem:(id)sender;
- (IBAction) authorizeMenuItem:(id)sender;

@end

NS_ASSUME_NONNULL_END
