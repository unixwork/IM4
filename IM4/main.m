//
//  main.m
//  IM4
//
//  Created by Olaf Wintermann on 11.08.23.
//

#import <Cocoa/Cocoa.h>

#include <strophe.h>
#include "xmpp.h"

int main(int argc, const char * argv[]) {
    xmpp_initialize();
    OTRL_INIT;
    
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
    }
    return NSApplicationMain(argc, argv);
}
