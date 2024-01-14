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

#import "LogWindowController.h"

@interface LogWindowController ()

@property NSMutableString *buffer;

@end

@implementation LogWindowController

- (id)initLogWindow {
    self = [self initWithWindowNibName:@"LogWindowController"];
    _buffer = [[NSMutableString alloc] init];
    
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    if(_buffer != nil) {
        size_t bufLen = _buffer.length;
        const char *bufStr = _buffer.UTF8String;
        _buffer = nil;
        [self addToLog:bufStr length:bufLen];
    }
}

- (void)addToLog:(const char *)str length:(size_t)length {
    NSString *logStr = [[NSString alloc]initWithBytes:str length:length encoding:NSUTF8StringEncoding ];
    if(!self.windowLoaded) {
        [_buffer appendString:logStr];
        return;
    }
    
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:logStr];
    
    [_log.textStorage appendAttributedString:attributedText];
    [_log scrollToEndOfDocument:nil];
}

- (IBAction) clearAction:(id)sender {
    NSTextStorage *textStorage = _log.textStorage;
    NSAttributedString *attributedText = [[NSAttributedString alloc] init];
    [textStorage setAttributedString:attributedText];
}

@end
