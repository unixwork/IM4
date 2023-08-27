//
//  OutlineViewController.m
//  IM4
//
//  Created by Olaf Wintermann on 11.08.23.
//

#import "OutlineViewController.h"

#import "AppDelegate.h"

@implementation OutlineViewController

- (id)init {
    self = [super init];
    _contacts = [[NSMutableArray alloc]init];
    Contact *c = [[Contact alloc] initGroup:@"Offline"];
    
    [_contacts addObject:c];
    
    return self;
}

- (void) refreshContacts:(Xmpp*)xmpp presence:(NSDictionary*)presence {
    [_contacts removeAllObjects];
    Contact *c = [[Contact alloc] initGroup:@"Contacts"];
    [_contacts addObject:c];
    
    for(int i=0;i<xmpp->ncontacts;i++) {
        XmppContact *x = &xmpp->contacts[i];
        
        NSString *name = nil;
        NSString *xid = nil;
        
        if(x->name) {
            name = [[NSString alloc] initWithCString:x->name encoding:NSUTF8StringEncoding];
        }
        if(x->jid) {
            xid = [[NSString alloc] initWithCString:x->jid encoding:NSUTF8StringEncoding];
        }
        if(name == nil) {
            name = xid;
        }
        Contact *contact = [[Contact alloc] initContact:name xid:xid];
        if([presence objectForKey:xid] != nil) {
            contact.presence = @"online";
        }
        
        [c addContact:contact];
    }
}

- (Contact*) contact:(NSString*)xid {
    NSMutableArray *stack = [[NSMutableArray alloc]initWithCapacity:4];
    [stack addObject:_contacts];
    
    Boolean update = false;
    while(stack.count > 0) {
        NSArray *list = [stack objectAtIndex:0];
        for(int i=0;i<list.count;i++) {
            Contact *c = [list objectAtIndex:i];
            NSArray *sub = c.contacts;
            if(sub != nil) {
                [stack addObject:sub];
            }
            if([c.xid isEqualTo:xid]) {
                return c;
            }
        }
        
        [stack removeObject:list];
    }
    
    return nil;
}

- (NSString*) contactName:(NSString*)xid {
    Contact *c = [self contact:xid];
    if(c) {
        return c.name;
    }
    return nil;
}

- (Boolean) updatePresence:(NSString*)status xid:(NSString*)xid {
    NSMutableArray *stack = [[NSMutableArray alloc]initWithCapacity:4];
    [stack addObject:_contacts];
    
    Boolean update = false;
    while(stack.count > 0) {
        NSArray *list = [stack objectAtIndex:0];
        for(int i=0;i<list.count;i++) {
            Contact *c = [list objectAtIndex:i];
            NSArray *sub = c.contacts;
            if(sub != nil) {
                [stack addObject:sub];
            }
            if([c.xid isEqualTo:xid]) {
                c.presence = status;
                update = true;
            }
        }
        
        [stack removeObject:list];
    }
    
    return update;
}

// Actions

- (IBAction) doubleAction:(NSOutlineView*)sender {
    NSInteger row = [sender clickedRow];
    Contact *c = [sender itemAtRow:row];
    //printf("clicked row: %d: %s\n", (int)row, [c.xid UTF8String]);
    
    if(c.xid != nil) {
        AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
        [app openConversation:c];
    }
}

- (IBAction) renameMenuItem:(id)sender {
    NSInteger row = _outlineView.clickedRow;
    Contact *c = [_outlineView itemAtRow:row];
    
    if(c.contacts == nil) {
        printf("rename contact\n");
        [_outlineView editColumn:0 row:row withEvent:[NSApp currentEvent] select:YES];
    }
}

- (IBAction) cellAction:(id)sender {
    printf("cell action\n");
}

// NSMenuDelegate implementation
- (void)menuNeedsUpdate:(NSMenu *)menu {
    //printf("needs update: %d\n", (int)_outlineView.clickedRow);
}

// NSOutlineViewDelegate implementation
- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    //printf("willDisplayCell\n");
    Contact *c = item;
    if ([cell isKindOfClass:[NSTextFieldCell class]]) {
        if(self->isEditing) {
            [cell setStringValue:c.name];
        }
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
        shouldEditTableColumn:(NSTableColumn *)tableColumn
               item:(id)item {
    Contact *c = item;
    if(c.contacts == nil) {
        self->isEditing = YES;
        return YES;
    }
    return NO;
}


// NSOutlineViewDataSource implementation

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    return item == NULL ? [self.contacts count] : [[item contacts]count];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    if (item == NULL) {
        return YES;
    }
    
    return [[item contacts] count] > 0 ? YES : NO;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    NSArray *a = item == NULL ? [self contacts] : [item contacts];
    return [a objectAtIndex:index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    Contact *contact = (Contact*)item;
    if([[tableColumn identifier] isEqualToString:@"colName"]) {
        return [contact displayName];
    }
    return @"-";
}

- (void)outlineView:(NSOutlineView *)outlineView
     setObjectValue:(id)object
     forTableColumn:(NSTableColumn *)tableColumn
             byItem:(id)item {
    Contact *contact = (Contact*)item;
    [contact setName:object];
    self->isEditing = NO;
}


@end
