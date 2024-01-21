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

#import "SettingsController.h"

#import "AppDelegate.h"

#import <CommonCrypto/CommonDigest.h>

#import "app.h"

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
@property (strong) IBOutlet NSTextField *otrFingerprint;

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
    
    NSString *templateFilePath = [self configFilePath:@"uitemplates.plist"];
    NSMutableDictionary *tplDict = [NSMutableDictionary dictionaryWithContentsOfFile:templateFilePath];
    if (tplDict) {
        _templateSettings = [[UITemplate alloc]initWithConfigDict:tplDict];
    } else {
        _templateSettings = [[UITemplate alloc]init];
    }
    
    // create ssl config if needed
    NSString *ssl_file = [self configFilePath:@"certs.pem"];
    isDir = false;
    if (![fileManager fileExistsAtPath:ssl_file isDirectory:&isDir]) {
        char *cmd = NULL;
        asprintf(&cmd, "security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain /Library/Keychains/System.keychain ~/Library/Keychains/login.keychain-db > \"%s\"", [ssl_file UTF8String]);
        system(cmd);
        free(cmd);
    }
    setenv("SSL_CERT_FILE", [ssl_file UTF8String], 0);
    
    
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
    
    _password.stringValue = @"";
    
    if(_fingerprint) {
        _otrFingerprint.stringValue = [NSString stringWithFormat:@"Fingerprint: %@", _fingerprint];
    }
}

- (BOOL)storeSettings {
    NSString *configFilePath = [self configFilePath:@"config.plist"];
    NSString *aliasFilePath = [self configFilePath:@"aliases.plist"];
    
    [_config writeToFile:configFilePath atomically:YES];
    [_aliases writeToFile:aliasFilePath atomically:YES];
    
    return true;
}

- (void) createFingerprintFromPubkey {
    if(_xmpp && _xmpp->userstate && _xmpp->userstate->privkey_root) {
        OtrlPrivKey *privkey_root = _xmpp->userstate->privkey_root;
        
        unsigned char fingerprint_data[CC_SHA1_DIGEST_LENGTH];
        CC_SHA1(privkey_root->pubkey_data, (CC_LONG)privkey_root->pubkey_datalen, fingerprint_data);
        
        NSMutableString *fingerprint_str = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
        for(int i=0;i<CC_SHA1_DIGEST_LENGTH;i++) {
            [fingerprint_str appendFormat:@"%02x", fingerprint_data[i]];
        }
        
        _fingerprint = fingerprint_str;
    }
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
    
    if(jid) {
        XmppSettings settings = {0};
        settings.jid = strdup([jid UTF8String]);
        if(password && password.length > 0) {
            settings.password = strdup([password UTF8String]);
        }
        settings.alias = alias ? strdup([alias UTF8String]) : NULL;
        settings.resource = resource ? strdup([resource UTF8String]) : NULL;
        settings.host = host ? strdup([host UTF8String]) : NULL;
        settings.port = port_num;
        settings.flags = XMPP_CONN_FLAG_MANDATORY_TLS;
        if(alias) {
            settings.alias = strdup([alias UTF8String]);
        }
        
        _xmpp = XmppCreate(settings);
        
        [self createFingerprintFromPubkey];
    }
}

- (void) recreateXmpp {
    if(!_xmpp) {
        [self createXmpp];
        return;
    }
    
    // not so nice way to re-create the Xmpp object
    // maybe rewrite it (or find a way to reconnect without recreating the object
    
    Xmpp *old = _xmpp;
    [self createXmpp];
    Xmpp *new = _xmpp;
    
    // save conversations from old Xmpp object
    XmppConversation **conv = old->conversations;
    size_t nconv = old->nconversations;
    size_t convalloc = old->conversationsalloc;
    
    // reuse old addr but use new content
    *old = *new;
    
    // restore conversations
    old->conversations = conv;
    old->nconversations = nconv;
    old->conversationsalloc = convalloc;
    
    _xmpp = old;
    // TODO: free
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

- (IBAction)otrGenKey:(id)sender {
    char *filename = app_configfile("otr.private_key");
    otrl_privkey_generate(_xmpp->userstate, filename, _xmpp->userstate->privkey_root->accountname, _xmpp->userstate->privkey_root->protocol);
    otrl_privkey_read(_xmpp->userstate, filename);
    
    [self createFingerprintFromPubkey];
    if(_fingerprint) {
        _otrFingerprint.stringValue = [NSString stringWithFormat:@"Fingerprint: %@", _fingerprint];
    }
}

@end
