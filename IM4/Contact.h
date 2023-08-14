//
//  Contact.h
//  IM4
//
//  Created by Olaf Wintermann on 11.08.23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Contact : NSObject

@property (copy) NSString *name;
@property (copy) NSString *xid;
@property (copy) NSString *presence;
@property (readonly, copy) NSMutableArray *contacts;

- (id)initContact:(NSString *) name xid:(NSString *)xid;
- (id)initGroup:(NSString *) name;
- (void)addContact:(Contact *)contact;
- (NSString*)displayName;

@end

NS_ASSUME_NONNULL_END
