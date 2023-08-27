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

@interface OutlineViewController : NSObject <NSOutlineViewDataSource, NSMenuDelegate, NSOutlineViewDelegate> {
    Boolean isEditing;
}

@property (copy) NSMutableArray *contacts;

@property (strong) IBOutlet NSOutlineView *outlineView;

- (void) refreshContacts:(Xmpp*)xmpp presence:(NSDictionary*)presence;

- (Contact*) contact:(NSString*)xid;

- (NSString*) contactName:(NSString*)xid;

- (Boolean) updatePresence:(NSString*)status xid:(NSString*)xid;

- (IBAction) doubleAction:(NSOutlineView*)sender;

- (IBAction) cellAction:(id)sender;

- (IBAction) renameMenuItem:(id)sender;

@end

NS_ASSUME_NONNULL_END
