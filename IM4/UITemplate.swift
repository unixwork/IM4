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

@objc class UITemplate: NSObject {
    private(set) var dict: NSMutableDictionary
    
    @objc override init() {
        self.dict = NSMutableDictionary()
        super.init()
    }
    
    @objc convenience init(configDict: NSMutableDictionary) {
        self.init()
        self.dict = configDict
    }
    
    @objc func xmppPresenceAway() -> String {
        return dict["xmpp.presence.away"] as? String ?? "[away] ";
    }

    @objc func setXmppPresenceAway(_ value: String) {
        dict["xmpp.presence.away"] = value
    }
    
    @objc func xmppPresenceChat() -> String {
        return dict["xmpp.presence.chat"] as? String ?? "[chat] ";
    }

    @objc func setXmppPresenceChat(_ value: String) {
        dict["xmpp.presence.chat"] = value
    }
    
    @objc func xmppPresenceDnd() -> String {
        return dict["xmpp.presence.dnd"] as? String ?? "[dnd] ";
    }

    @objc func setXmppPresenceDnd(_ value: String) {
        dict["xmpp.presence.dnd"] = value
    }
    
    @objc func xmppPresenceIconOnline() -> String {
        return dict["xmpp.presenceicon.online"] as? String ?? "🟢";
    }

    @objc func setXmppPresenceIconOnline(_ value: String) {
        dict["xmpp.presenceicon.online"] = value
    }
    
    @objc func xmppPresenceIconOffline() -> String {
        return dict["xmpp.presenceicon.offline"] as? String ?? "🔴";
    }

    @objc func setXmppPresenceIconOffline(_ value: String) {
        dict["xmpp.presenceicon.offline"] = value
    }
    
    @objc func xmppPresenceIconAway() -> String {
        return dict["xmpp.presenceicon.away"] as? String ?? "🟡​";
    }

    @objc func setXmppPresenceIconAway(_ value: String) {
        dict["xmpp.presenceicon.away"] = value
    }
    
    @objc func xmppPresenceIconChat() -> String {
        return dict["xmpp.presenceicon.chat"] as? String ?? "💬";
    }

    @objc func setXmppPresenceIconChat(_ value: String) {
        dict["xmpp.presenceicon.chat"] = value
    }
    
    @objc func xmppPresenceIconDnd() -> String {
        return dict["xmpp.presenceicon.dnd"] as? String ?? "🟠​";
    }

    @objc func setXmppPresenceIconDnd(_ value: String) {
        dict["xmpp.presenceicon.dnd"] = value
    }
    
    @objc func xmppPresenceIconXA() -> String {
        return dict["xmpp.presenceicon.xa"] as? String ?? "🟣";
    }

    @objc func setXmppPresenceIconXA(_ value: String) {
        dict["xmpp.presenceicon.xa"] = value
    }
    
    @objc func otrGoneSecure() -> String {
        return dict["otr.gonesecure"] as? String ?? "otr: gone secure"
    }

    @objc func setOtrGoneSecure(_ value: String) {
        dict["otr.gonesecure"] = value
    }

    @objc func otrGoneInsecure() -> String {
        return dict["otr.goneinsecure"] as? String ?? "otr: gone insecure"
    }

    @objc func setOtrGoneInsecure(_ value: String) {
        dict["otr.goneinsecure"] = value
    }

    @objc func otrDisabled() -> String {
        return dict["otr.disabled"] as? String ?? "otr disabled"
    }

    @objc func setOtrDisabled(_ value: String) {
        dict["otr.disabled"] = value
    }

    @objc func otrSecure() -> String {
        return dict["otr.secure"] as? String ?? "🔒"
    }

    @objc func setOtrSecure(_ value: String) {
        dict["otr.secure"] = value
    }

    @objc func otrInsecure() -> String {
        return dict["otr.unsecure"] as? String ?? ""
    }

    @objc func setOtrInsecure(_ value: String) {
        dict["otr.unsecure"] = value
    }

    @objc func chatStateComposing() -> String {
        return dict["chatstate.composing"] as? String ?? "composing"
    }

    @objc func setChatStateComposing(_ value: String) {
        dict["chatstate.composing"] = value
    }

    @objc func chatStatePaused() -> String {
        return dict["chatstate.paused"] as? String ?? "paused"
    }

    @objc func setChatStatePaused(_ value: String) {
        dict["chatstate.paused"] = value
    }

    @objc func chatStateInactive() -> String {
        return dict["chatstate.inactive"] as? String ?? "inactive"
    }

    @objc func setChatStateInactive(_ value: String) {
        dict["chatstate.inactive"] = value
    }

    @objc func chatStateGone() -> String {
        return dict["chatstate.gone"] as? String ?? "gone"
    }

    @objc func setChatStateGone(_ value: String) {
        dict["chatstate.gone"] = value
    }

    @objc func msgInPrefixFormat() -> String {
        return dict["msg.in.format"] as? String ?? "< %s(%t) %a: "
    }

    @objc func setMsgInPrefixFormat(_ value: String) {
        dict["msg.in.format"] = value
    }

    @objc func msgOutPrefixFormat() -> String {
        return dict["msg.out.format"] as? String ?? "> %s(%t) %a: "
    }

    @objc func setMsgOutPrefixFormat(_ value: String) {
        dict["msg.out.format"] = value
    }

    @objc func htmlMsgInFormat() -> String? {
        return dict["msg.htmlin.format"] as? String
    }

    @objc func setHtmlMsgInFormat(_ value: String?) {
        dict["msg.htmlin.format"] = value
    }

    @objc func htmlMsgOutFormat() -> String? {
        return dict["msg.htmlout.format"] as? String
    }

    @objc func setHtmlMsgOutFormat(_ value: String?) {
        dict["msg.htmlout.format"] = value
    }
    
    @objc func msgPrefixFormat(format: String, xid: String, alias: String, secure: Bool) -> String {
        var fstr = ""
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        let time = dateFormatter.string(from: currentDate)

        var placeholder = false

        for char in format {
            if placeholder {
                switch char {
                    case "t":
                        fstr.append(time)
                    case "x":
                        fstr.append(xid)
                    case "a":
                        fstr.append(alias)
                    case "s":
                        fstr.append(secure ? otrSecure() : otrInsecure())
                    default:
                        fstr.append(char)
                    }
                placeholder = false
            } else {
                if char == "%" {
                    placeholder = true
                } else {
                    fstr.append(char)
                }
            }
        }

        return fstr
    }
}
