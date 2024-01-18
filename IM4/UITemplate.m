//
//  UITemplate.m
//  IM4
//
//  Created by Olaf Wintermann on 18.01.24.
//

#import "UITemplate.h"

@implementation UITemplate

- (id) init:(NSMutableDictionary*)configDict {
    _dict = configDict;
    return self;
}

- (id) initDefault {
    _dict = [[NSMutableDictionary alloc] init];
    return self;
}

- (NSString*) otrGoneSecure {
    NSString *val = [_dict valueForKey:@"otr.gonesecure"];
    if(val) {
        return val;
    } else {
        return @"otr: gone secure";
    }
}

- (NSString*) otrGoneInsecure {
    NSString *val = [_dict valueForKey:@"otr.goneinsecure"];
    if(val) {
        return val;
    } else {
        return @"otr: gone insecure";
    }
}

- (NSString*) otrDisabled {
    NSString *val = [_dict valueForKey:@"otr.disabled"];
    if(val) {
        return val;
    } else {
        return @"otr disabled";
    }
}

- (NSString*) otrSecure {
    NSString *val = [_dict valueForKey:@"otr.secure"];
    if(val) {
        return val;
    } else {
        return @"🔒";
    }
}
- (NSString*) otrInsecure {
    NSString *val = [_dict valueForKey:@"otr.unsecure"];
    if(val) {
        return val;
    } else {
        return @"";
    }
}
- (NSString*) chatStateComposing {
    NSString *val = [_dict valueForKey:@"chatstate.composing"];
    if(val) {
        return val;
    } else {
        return @"composing";
    }
}

- (NSString*) chatStatePaused {
    NSString *val = [_dict valueForKey:@"chatstate.paused"];
    if(val) {
        return val;
    } else {
        return @"paused";
    }
}

- (NSString*) chatStateInactive {
    NSString *val = [_dict valueForKey:@"chatstate.inactive"];
    if(val) {
        return val;
    } else {
        return @"inactive";
    }
}

- (NSString*) chatStateGone {
    NSString *val = [_dict valueForKey:@"chatstate.gone"];
    if(val) {
        return val;
    } else {
        return @"gone";
    }
}

@end
