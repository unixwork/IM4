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

import Cocoa

@objc class TemplateSettingsController: NSWindowController {
    
    @IBOutlet var otrGoneSecure : NSTextField!
    @IBOutlet var otrGoneInsecure : NSTextField!
    @IBOutlet var otrDisabled : NSTextField!
    @IBOutlet var secureSymbol : NSTextField!
    @IBOutlet var unsecureSymbol : NSTextField!
    @IBOutlet var chatStateComposing : NSTextField!
    @IBOutlet var chatStatePaused : NSTextField!
    @IBOutlet var chatStateInactive : NSTextField!
    @IBOutlet var chatStateGone : NSTextField!
    @IBOutlet var incomingMessageFormat : NSTextField!
    @IBOutlet var outgoingMessageFormat : NSTextField!
    @IBOutlet var incomingMsgHtml : NSTextField!
    @IBOutlet var outgoingMsgHtml: NSTextField!

    var templateStrings : UITemplate!
    
    @objc init(template : UITemplate) {
        super.init(window: nil)
        templateStrings = template
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        otrGoneSecure.stringValue = templateStrings.otrGoneSecure()
        otrGoneInsecure.stringValue = templateStrings.otrGoneInsecure()
        otrDisabled.stringValue = templateStrings.otrDisabled()
        secureSymbol.stringValue = templateStrings.otrSecure()
        unsecureSymbol.stringValue = templateStrings.otrInsecure()
        chatStateComposing.stringValue = templateStrings.chatStateComposing()
        chatStatePaused.stringValue = templateStrings.chatStatePaused()
        chatStateInactive.stringValue = templateStrings.chatStateInactive()
        chatStateGone.stringValue = templateStrings.chatStateGone()
        incomingMessageFormat.stringValue = templateStrings.msgInPrefixFormat()
        outgoingMessageFormat.stringValue = templateStrings.msgOutPrefixFormat()
        
        if let htmlInFormat = templateStrings.htmlMsgInFormat() {
            incomingMsgHtml.stringValue = htmlInFormat
        }
        if let htmlOutFormat = templateStrings.htmlMsgOutFormat() {
            outgoingMsgHtml.stringValue = htmlOutFormat
        }
    }
    
    override var windowNibName: String! {
        return "TemplateSettingsController"
    }
    
    
}
