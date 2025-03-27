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
#import "regexreplace.h"

#import <sys/stat.h>
#import <unistd.h>
#import <errno.h>
#import <time.h>

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
@property (strong) IBOutlet NSComboBox  *logLevel;
@property (strong) IBOutlet NSComboBox  *presenceStatus;
@property (strong) IBOutlet NSComboBox  *unencryptedMessagesBox;
@property (strong) IBOutlet NSSwitch    *automaticDashSub;
@property (strong) IBOutlet NSSwitch    *automaticQuoteSub;

@property int editFont; // 1: ChatFont, 2: InputFont

@end

@implementation SettingsController

- (id)initSettings {
    self = [self initWithWindowNibName:@"SettingsController"];
    _xmpp = NULL;
    _editFont = 0;
    
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
    
    // text replacement rules
    NSString *rttRulesFilePath = [self configFilePath:@ REGEX_TEXT_REPLACEMENT_RULES_FILE];
    if(load_rules_config([rttRulesFilePath UTF8String])) {
        printf("cannot load %s\n", REGEX_TEXT_REPLACEMENT_RULES_FILE);
    }
    
    NSString *templateFilePath = [self configFilePath:@"uitemplates.plist"];
    _templateSettingsDict = [NSMutableDictionary dictionaryWithContentsOfFile:templateFilePath];
    if (!_templateSettingsDict) {
        _templateSettingsDict = [[NSMutableDictionary alloc] init];
    }
    _templateSettings = [[UITemplate alloc]initWithConfigDict:_templateSettingsDict];
    
    NSNumber *logLevelNum = [_config valueForKey:@"loglevel"];
    if(logLevelNum) {
        int lvl = logLevelNum.intValue;
        if(lvl >= 0 && lvl <= 4) {
            XmppSetLogLevel(lvl);
        }
    }
    
    NSNumber *presence = [_config valueForKey:@"presence"];
    _StartupPresence = 1; // default status: online
    if(presence) {
        int ps = presence.intValue;
        if(ps >= 0 && ps <= 5) {
            _StartupPresence = ps;
        }
    }
    
    NSNumber *unsafeMessages = [_config valueForKey:@"unencrypted"];
    _UnencryptedMessages = 0;
    if(unsafeMessages) {
        int um = unsafeMessages.intValue;
        if(um >= 0 && um <= 2) {
            _UnencryptedMessages = um;
        }
    }
    
    NSNumber *textSubDash = [_config valueForKey:@"subdash"];
    if(textSubDash) {
        _TextDefaultSubDash = (BOOL)textSubDash.intValue;
    } else {
        _TextDefaultSubDash = YES;
    }
    NSNumber *textSubQuote = [_config valueForKey:@"subquote"];
    if(textSubQuote) {
        _TextDefaultSubQuote = (BOOL)textSubQuote.intValue;
    } else {
        _TextDefaultSubQuote = YES;
    }
    
    
    // create ssl config if needed
    NSString *ssl_file = [self configFilePath:@"certs.pem"];
    bool importCerts = false;
    struct stat s;
    if(stat([ssl_file UTF8String], &s)) {
        if(errno == ENOENT) {
            XmppLog("IM4: import certs");
            importCerts = true;
        }
    } else {
        if(S_ISREG(s.st_mode)) {
            struct stat chs;
            if(!stat("/System/Library/Keychains/SystemRootCertificates.keychain", &chs)) {
                if(chs.st_mtime > s.st_mtime) {
                    importCerts = true;
                }
            }
            if(!stat("/Library/Keychains/System.keychain", &chs)) {
                if(chs.st_mtime > s.st_mtime) {
                    importCerts = true;
                }
            }
            char *user_home = getenv("HOME");
            char *login_keychain_path;
            asprintf(&login_keychain_path, "%s%s", user_home, "/Library/Keychains/login.keychain-db");
            if(!stat(login_keychain_path, &chs)) {
                if(chs.st_mtime > s.st_mtime) {
                    importCerts = true;
                }
            }
            free(login_keychain_path);
            
            if(importCerts) {
                XmppLog("IM4: reimport certs");
            }
        }
    }
    
    if(importCerts) {
        char *cmd = NULL;
        asprintf(&cmd, "security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain /Library/Keychains/System.keychain ~/Library/Keychains/login.keychain-db > \"%s\"", [ssl_file UTF8String]);
        XmppLog(cmd);
        system(cmd);
        free(cmd);
    }
    
    setenv("SSL_CERT_FILE", [ssl_file UTF8String], 0);
    
    // get default fonts
    NSString *chatFontName = [_config valueForKey:@"chatfontname"];
    NSNumber *chatFontSize = [_config valueForKey:@"chatfontsize"];
    NSString *inputFontName = [_config valueForKey:@"inputfontname"];
    NSNumber *inputFontSize = [_config valueForKey:@"inputfontsize"];
    
    NSTextView *textview = [[NSTextView alloc] init];
    
    if(chatFontName) {
        int fontSize = chatFontSize ? chatFontSize.intValue : 11;
        _ChatFont = [NSFont fontWithName:chatFontName size:fontSize];
    }
    if(inputFontName) {
        int fontSize = inputFontSize ? inputFontSize.intValue : 11;
        _InputFont = [NSFont fontWithName:inputFontName size:fontSize];
    }
    
    if(_ChatFont == nil) {
        _ChatFont = textview.font;
    }
    if(_InputFont == nil) {
        _InputFont = textview.font;
    }
    
    [self createXmpp];
    return self;
}

- (void)initInputFields {
    NSString *jid = [_config valueForKey:@"jid"];
    NSString *alias = [_config valueForKey:@"alias"];
    NSString *resource = [_config valueForKey:@"resource"];
    NSString *host = [_config valueForKey:@"host"];
    NSString *port = [_config valueForKey:@"port"];
    
    _jid.stringValue = jid ? jid : @"";
    _alias.stringValue = alias ? alias : @"";
    _resource.stringValue = resource ? resource : @"";
    _host.stringValue = host ? host : @"";
    _port.stringValue = port ? port : @"";
    
    _password.stringValue = @"";
    
    [_logLevel selectItemAtIndex:XmppGetLogLevel()];
    [_presenceStatus selectItemAtIndex:_StartupPresence];
    [_unencryptedMessagesBox selectItemAtIndex:_UnencryptedMessages];
    
    _automaticDashSub.state = _TextDefaultSubDash ? NSControlStateValueOn : NSControlStateValueOff;
    _automaticQuoteSub.state = _TextDefaultSubQuote ? NSControlStateValueOn : NSControlStateValueOff;
    
    _TmpChatFont = _ChatFont;
    _TmpInputFont = _InputFont;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    self.window.title = @"Settings";
    
    [self initInputFields];
    
    int logLevel = XmppGetLogLevel();
    [_logLevel selectItemAtIndex:logLevel];
    [_presenceStatus selectItemAtIndex:_StartupPresence];
    
    if(_fingerprint) {
        _otrFingerprint.stringValue = [NSString stringWithFormat:@"Fingerprint: %@", _fingerprint];
    }
}

- (BOOL)storeSettings {
    NSString *configFilePath = [self configFilePath:@"config.plist"];
    NSString *aliasFilePath = [self configFilePath:@"aliases.plist"];
    NSString *templateFilePath = [self configFilePath:@"uitemplates.plist"];
    
    [_config writeToFile:configFilePath atomically:YES];
    [_aliases writeToFile:aliasFilePath atomically:YES];
    [_templateSettingsDict writeToFile:templateFilePath atomically:YES];
    
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
    
    XmppSettings settings = {0}; // currently unused by XmppRecreate
    XmppRecreate(_xmpp, settings);
}

- (void) setAlias: (NSString*)alias forXid:(NSString*)xid {
    [_aliases setValue:alias forKey:xid];
}

- (NSString*) getAlias: (NSString*)xid {
    return [_aliases valueForKey:xid];
}

- (IBAction)okAction:(id)sender {
    _ChatFont = _TmpChatFont;
    _InputFont = _TmpInputFont;
    AppDelegate *app = (AppDelegate *)[NSApplication sharedApplication].delegate;
    [app updateFonts:_ChatFont inputFont:_InputFont];
    
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
    
    int presence = (int)_presenceStatus.indexOfSelectedItem;
    _StartupPresence = presence;
    NSNumber *num = [[NSNumber alloc]initWithInt:presence];
    [_config setValue:num forKey:@"presence"];
    _UnencryptedMessages = (int)_unencryptedMessagesBox.indexOfSelectedItem;
    NSNumber *unencryptedMessages = [[NSNumber alloc]initWithInt:_UnencryptedMessages];
    [_config setValue:unencryptedMessages forKey:@"unencrypted"];
    
    _TextDefaultSubDash = _automaticDashSub.state == NSControlStateValueOn ? YES : NO;
    _TextDefaultSubQuote = _automaticQuoteSub.state == NSControlStateValueOn ? YES : NO;
    NSNumber *subdash = [[NSNumber alloc] initWithBool:_TextDefaultSubDash];
    NSNumber *subquote = [[NSNumber alloc] initWithBool:_TextDefaultSubQuote];
    [_config setValue:subdash forKey:@"subdash"];
    [_config setValue:subquote forKey:@"subquote"];
    
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
    
    NSString *chatFontName = _ChatFont.familyName;
    NSNumber *chatFontSize = [[NSNumber alloc] initWithInt:_ChatFont.pointSize];
    
    NSString *inputFontName = _InputFont.familyName;
    NSNumber *inputFontSize = [[NSNumber alloc] initWithInt:_InputFont.pointSize];
    
    [_config setValue:chatFontName forKey:@"chatfontname"];
    [_config setValue:chatFontSize forKey:@"chatfontsize"];
    [_config setValue:inputFontName forKey:@"inputfontname"];
    [_config setValue:inputFontSize forKey:@"inputfontsize"];
    
    [[self window] close];
}

- (IBAction)cancelAction:(id)sender {
    [self initInputFields];
    [[self window] close];
}



- (void)windowWillClose:(NSNotification *)notification {
    
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

- (IBAction)logLevelSelected:(id)sender {
    int lvl = (int)_logLevel.indexOfSelectedItem;
    XmppSetLogLevel(lvl);
    NSNumber *num = [[NSNumber alloc]initWithInt:lvl];
    [_config setValue:num forKey:@"loglevel"];
}

- (IBAction)openTemplateSettings:(id)sender {
    if(_tplController == nil) {
        _tplController = [[TemplateSettingsController alloc] initWithTemplate:_templateSettings];
    }
    [_tplController showWindow:nil];
}

- (void)changeFont:(NSFontManager*)fontManager {
    if(_editFont == 1) {
        _TmpChatFont = [fontManager convertFont:_ChatFont];
    } else {
        _TmpInputFont = [fontManager convertFont:_InputFont];
    }
}

- (void) openFontPanel {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSFontPanel *fontPanel = [fontManager fontPanel:YES];
    [fontPanel makeKeyAndOrderFront:self];
}

- (IBAction)selectChatFont:(id)sender {
    _editFont = 1;
    [self openFontPanel];
}

- (IBAction)selectMessageInputfont:(id)sender {
    _editFont = 2;
    [self openFontPanel];
}

@end
