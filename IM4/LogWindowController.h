//
//  LogWindowController.h
//  IM4
//
//  Created by Olaf Wintermann on 03.01.24.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface LogWindowController : NSWindowController

@property (strong) IBOutlet NSTextView *log;

- (id)initLogWindow;

- (void)addToLog:(const char *)str length:(size_t)length;


@end

NS_ASSUME_NONNULL_END
