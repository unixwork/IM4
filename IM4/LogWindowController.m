//
//  LogWindowController.m
//  IM4
//
//  Created by Olaf Wintermann on 03.01.24.
//

#import "LogWindowController.h"

@interface LogWindowController ()

@end

@implementation LogWindowController

- (id)initLogWindow {
    self = [self initWithWindowNibName:@"LogWindowController"];
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (void)addToLog:(const char *)str length:(size_t)length {
    NSData *data = [NSData dataWithBytes:str length:length];
    NSDictionary *options = @{NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)};
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithHTML:data
                                                                          options:options
                                                               documentAttributes:nil];
    
    [_log.textStorage appendAttributedString:attributedText];
    [_log scrollToEndOfDocument:nil];
}

@end
