//
//  ConversationWindowController.h
//  IM4
//
//  Created by Olaf Wintermann on 13.08.23.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConversationWindowController : NSWindowController<NSWindowDelegate>

@property (copy) NSString* xid;

- (id)initConversation:(NSString*)xid;

- (IBAction) testAction:(id)sender;

@end

NS_ASSUME_NONNULL_END
