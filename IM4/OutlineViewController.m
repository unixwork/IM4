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
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    if(_tpl == nil) {
        _tpl = app.settingsController.templateSettings;
    }
    
    SettingsController *settings = app.settingsController;
    if(!xmpp) {
        return;
    }
    
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
            if(xid) {
                name = [settings getAlias:xid];
            }
            if(name == nil) {
                name = xid;
            }
        }
        
        Contact *contact = [[Contact alloc] initContact:name xid:xid];
        if(x->subscription) {
            contact.subscription = [[NSString alloc] initWithCString:x->subscription encoding:NSUTF8StringEncoding];
        }
        Presence *ps = [presence objectForKey:xid];
        if(ps != nil) {
            PresenceStatus *presenceStatus = [ps getRelevantPresenceStatus];
            contact.presence = presenceStatus;
        }
        
        [c addContact:contact];
    }
    
    [self performSelectorOnMainThread:@selector(expandContact:)
                                   withObject:c
                                waitUntilDone:NO];
}

- (void) expandContact:(id)c {
    [_outlineView expandItem:c];
}

- (void) clearContacts {
    [_contacts removeAllObjects];
    Contact *c = [[Contact alloc] initGroup:@"Offline"];
    [_contacts addObject:c];
}

- (Contact*) contact:(NSString*)xid {
    NSMutableArray *stack = [[NSMutableArray alloc]initWithCapacity:4];
    [stack addObject:_contacts];
    
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

- (Boolean) updateContact:(NSString*)xid updateStatus:(Boolean)updateStatus presence:(nullable PresenceStatus*)presence unread:(int)unread {
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
                if(unread >= 0) {
                    c.unread = unread;
                }
                if(updateStatus) {
                    c.presence = presence;
                }
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
        //printf("rename contact\n");
        self->isEditing = YES;
        [_outlineView editColumn:0 row:row withEvent:[NSApp currentEvent] select:YES];
    }
}

- (IBAction) cellAction:(id)sender {
    //printf("cell action\n");
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

- (NSString *) outlineView:(NSOutlineView *) outlineView
            toolTipForCell:(NSCell *) cell
                      rect:(NSRectPointer) rect
               tableColumn:(NSTableColumn *) tableColumn
                      item:(id) item
             mouseLocation:(NSPoint) mouseLocation {
    Contact *c = item;
    return [c tooltip];
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
        return [contact displayName: _tpl];
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
    
    // update aliases
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    SettingsController *settings = app.settingsController;
    
    // update alias in the settings (which contains a xid-alias map)
    [settings setAlias:contact.name forXid:contact.xid];
    
    // update the alias in an open conversation, if one exists
    [app updateConversationAlias:contact.xid newAlias:contact.name];
}


@end
