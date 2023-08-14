//
//  OutlineViewController.h
//  IM4
//
//  Created by Olaf Wintermann on 11.08.23.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import "Contact.h"

#include "xmpp.h"

NS_ASSUME_NONNULL_BEGIN

@interface OutlineViewController : NSObject <NSOutlineViewDataSource>

@property (copy) NSMutableArray *contacts;

- (void) refreshContacts:(Xmpp*)xmpp presence:(NSDictionary*)presence;

- (Boolean) updatePresence:(NSString*)status xid:(NSString*)xid;

- (IBAction) doubleAction:(NSOutlineView*)sender;

@end

NS_ASSUME_NONNULL_END
