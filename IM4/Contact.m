//
//  Contact.m
//  IM4
//
//  Created by Olaf Wintermann on 11.08.23.
//

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

@end
