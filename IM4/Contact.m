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

#import "Contact.h"

@implementation Contact

- (id)initContact:(NSString *) name xid:(NSString *)xid {
    _name = [name copy];
    _xid = [xid copy];
    _contacts = NULL;
    return self;
}

- (id)initGroup:(NSString *) name {
    _name = [name copy];
    _xid = NULL;
    _contacts = [[NSMutableArray alloc] init];
    return self;
}

- (void)addContact:(Contact *)contact {
    if(_contacts != NULL) {
        [_contacts addObject:contact];
    }
}

- (NSString*)displayName {
    if(_contacts != nil) {
        return _name;
    }
    
    NSString *name = _name == nil ? _xid : _name;
    NSString *status = _presence == nil ? @"🔴" : @"🟢";
    NSString *displayName = [[NSString alloc]initWithFormat:@"%@ %@%@", status, name, _unread != 0 ? @"*" : @""];
    return displayName;
}

@end
