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

- (NSString*) msgInPrefixFormat {
    NSString *val = [_dict valueForKey:@"msg.in.format"];
    if(val) {
        return val;
    } else {
        return @"< (%t) %a: ";
    }
}

- (NSString*) msgOutPrefixFormat {
    NSString *val = [_dict valueForKey:@"msg.out.format"];
    if(val) {
        return val;
    } else {
        return @"> (%t) %a: ";
    }
}


- (NSString*) msgPrefixFormat:(NSString*)format xid:(NSString*)xid alias:(NSString*)alias secure:(Boolean)secure {
    NSMutableString *fstr = [[NSMutableString alloc] init];
    
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss"];
    NSString *time = [dateFormatter stringFromDate:currentDate];
    
    __block Boolean placeholder = false;
    [format enumerateSubstringsInRange:NSMakeRange(0, [format length])  options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *outStop) {

        const char *s = [substring UTF8String];
        char c = *s;
        
        
        if(placeholder) {
            switch(c) {
                default: {
                    [fstr appendString:substring];
                    break;
                }
                case 't': {
                    [fstr appendString:time];
                    break;
                }
                case 'x': {
                    [fstr appendString:xid];
                    break;
                }
                case 'a': {
                    [fstr appendString:alias];
                    break;
                }
                case 's': {
                    [fstr appendString:secure ? self.otrSecure : self.otrInsecure];
                    break;
                }
            }
            placeholder = false;
        } else {
            if(c == '%') {
                placeholder = true;
            } else {
                [fstr appendString:substring];
            }
        }
    }];
    
    
    return fstr;
}

@end
