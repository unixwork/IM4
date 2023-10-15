//
//  SettingsController.m
//  IM4
//
//  Created by Olaf Wintermann on 27.08.23.
//

#import "SettingsController.h"

@interface SettingsController ()

@property (strong) IBOutlet NSTextField *jid;
@property (strong) IBOutlet NSTextField *password;
@property (strong) IBOutlet NSTextField *alias;
@property (strong) IBOutlet NSTextField *host;
@property (strong) IBOutlet NSTextField *port;

@end

@implementation SettingsController

- (id)initSettings {
    self = [self initWithWindowNibName:@"SettingsController"];
    _xmpp = NULL;
    
    // load settings
    NSString *configFilePath = [self configFilePath:@"config.plist"];
    _config = [NSMutableDictionary dictionaryWithContentsOfFile:configFilePath];
    if (_config == nil) {
        _config = [[NSMutableDictionary alloc]init];
    }
    
    NSString *aliasFilePath = [self configFilePath:@"aliases.plist"];
    _aliases = [NSMutableDictionary dictionaryWithContentsOfFile:aliasFilePath];
    if (_aliases == nil) {
        _aliases = [[NSMutableDictionary alloc]init];
    }
    
    [self createXmpp];
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    self.window.title = @"Settings";
    
    printf("window did load\n");
}

- (BOOL)storeSettings {
    NSString *configFilePath = [self configFilePath:@"config.plist"];
    NSString *aliasFilePath = [self configFilePath:@"aliases.plist"];
    
    [_config writeToFile:configFilePath atomically:YES];
    [_aliases writeToFile:aliasFilePath atomically:YES];
    
    return true;
}

- (NSString*) configFilePath: (NSString*)fileName {
    NSArray *path = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    if([path count] == 0) {
        return nil;
    }
    
    NSString *configDir = [path objectAtIndex:0];
    return [configDir stringByAppendingFormat:@"/%@/%@", IM4_APPNAME_NS, fileName];
}

- (void) createXmpp {
    XmppSettings settings = {0};
    
    NSString *jid = [_config valueForKey:@"jid"];
    NSString *password = [_config valueForKey:@"password"];
    NSString *alias = [_config valueForKey:@"alias"];
    
    if(jid && password) {
        XmppSettings settings = {0};
        settings.jid = strdup([jid UTF8String]);
        settings.password = strdup([password UTF8String]);
        settings.flags = XMPP_CONN_FLAG_MANDATORY_TLS;
        if(alias) {
            settings.alias = strdup([alias UTF8String]);
        }
        
        _xmpp = XmppCreate(settings);
    }
}

- (void) setAlias: (NSString*)alias forXid:(NSString*)xid {
    [_aliases setValue:alias forKey:xid];
}

- (NSString*) getAlias: (NSString*)xid {
    return [_aliases valueForKey:xid];
}

- (IBAction)testAction:(id)sender {
    printf("test action\n");
}

- (IBAction)okAction:(id)sender {
    NSString *jid = _jid.stringValue;
    NSString *password = _password.stringValue;
    NSString *alias = _alias.stringValue;
    NSString *host = _host.stringValue;
    NSString *port = _port.stringValue;
    printf("jid: %s\npassword: %s\nalias: %s\nhost: %s\nport: %s\n", jid.UTF8String, password.UTF8String, alias.UTF8String, host.UTF8String, port.UTF8String);
}

- (IBAction)cancelAction:(id)sender {
    
}


- (void)windowWillClose:(NSNotification *)notification {
    printf("window close\n");
}

@end
