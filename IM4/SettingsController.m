//
//  SettingsController.m
//  IM4
//
//  Created by Olaf Wintermann on 27.08.23.
//

#import "SettingsController.h"

#import "AppDelegate.h"


static bool nsstreq(NSString *s1, NSString *s2) {
    if(s1 == s2) {
        return true; // equal objects or both nil
    }
    if(!s1 || !s2) {
        return false; // one of them is nil
    }
    
    return [s1 compare:s2] == NSOrderedSame;
}

@interface SettingsController ()

@property (strong) IBOutlet NSTextField *jid;
@property (strong) IBOutlet NSTextField *password;
@property (strong) IBOutlet NSTextField *alias;
@property (strong) IBOutlet NSTextField *resource;
@property (strong) IBOutlet NSTextField *host;
@property (strong) IBOutlet NSTextField *port;

@end

@implementation SettingsController

- (id)initSettings {
    self = [self initWithWindowNibName:@"SettingsController"];
    _xmpp = NULL;
    
    // check config dir
    NSString *configDir = [self configFilePath:@""];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = false;
    if (![fileManager fileExistsAtPath:configDir isDirectory:&isDir]) {
        NSError *error = nil;
        if (![fileManager createDirectoryAtPath:configDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Error creating directory: %@", error);
            exit(10);
        }
    } else if(!isDir) {
        exit(11);
    }
        
    
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
    
    NSString *jid = [_config valueForKey:@"jid"];
    NSString *alias = [_config valueForKey:@"alias"];
    NSString *resource = [_config valueForKey:@"resource"];
    NSString *host = [_config valueForKey:@"host"];
    NSString *port = [_config valueForKey:@"port"];
    
    if(jid) {
        _jid.stringValue = jid;
    }
    if(alias) {
        _alias.stringValue = alias;
    }
    if(resource) {
        _resource.stringValue = resource;
    }
    if(host) {
        _host.stringValue = host;
    }
    if(port) {
        _port.stringValue = port;
    }
    
    self.password.stringValue = @"";
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
    NSString *resource = [_config valueForKey:@"resource"];
    NSString *host = [_config valueForKey:@"host"];
    NSString *port = [_config valueForKey:@"port"];
    NSInteger port_num = port ? [port integerValue] : 0;
    
    if(jid && password) {
        XmppSettings settings = {0};
        settings.jid = strdup([jid UTF8String]);
        settings.password = strdup([password UTF8String]);
        settings.alias = alias ? strdup([alias UTF8String]) : NULL;
        settings.resource = resource ? strdup([resource UTF8String]) : NULL;
        settings.host = host ? strdup([host UTF8String]) : NULL;
        settings.port = port_num;
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
    NSString *resource = _resource.stringValue;
    NSString *host = _host.stringValue;
    NSString *port = _port.stringValue;
    
    NSString *config_jid = [_config valueForKey:@"jid"];
    
    bool restartConnection = !nsstreq(jid, config_jid);
    [_config setValue:jid forKey:@"jid"];
    if([password length] > 0) {
        [_config setValue:password forKey:@"password"];
    }
    [_config setValue:alias forKey:@"alias"];
    [_config setValue:resource forKey:@"resource"];
    [_config setValue:host forKey:@"host"];
    [_config setValue:port forKey:@"port"];
    
    if(restartConnection) {
        // create new xmpp object
        [self createXmpp];
        
        // tell the app to restart the xmpp connection,
        // which will also clear the old xmpp object in the app
        AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
        [app startXmpp];
    } else {
        // TODO: update alias via xmpp call
    }
    
    [[self window] close];
}

- (IBAction)cancelAction:(id)sender {
    [[self window] close];
}


- (void)windowWillClose:(NSNotification *)notification {
    printf("window close\n");
}

@end
