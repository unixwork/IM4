//
//  SettingsController.h
//  IM4
//
//  Created by Olaf Wintermann on 27.08.23.
//

#import <Cocoa/Cocoa.h>
#import "xmpp.h"

#define IM4_APPNAME "IM4TEST"
#define IM4_APPNAME_NS @ IM4_APPNAME

NS_ASSUME_NONNULL_BEGIN

@interface SettingsController : NSWindowController<NSWindowDelegate>

@property (readonly) Xmpp *xmpp;

@property (readonly) NSDictionary *config;
@property (readonly) NSDictionary *aliases;

@property (copy) NSString *fingerprint;

- (id)initSettings;

- (void) createXmpp;

- (void) recreateXmpp;

- (NSString*) configFilePath: (NSString*)fileName;

- (void) setAlias: (NSString*)alias forXid:(NSString*)xid;

- (NSString*) getAlias: (NSString*)xid;

- (BOOL) storeSettings;

- (void) createFingerprintFromPubkey;

- (IBAction)testAction:(id)sender;

- (IBAction)okAction:(id)sender;

- (IBAction)cancelAction:(id)sender;

- (IBAction)otrGenKey:(id)sender;


@end

NS_ASSUME_NONNULL_END
