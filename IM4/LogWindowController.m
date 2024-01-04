//
//  LogWindowController.m
//  IM4
//
//  Created by Olaf Wintermann on 03.01.24.
//

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

@end
