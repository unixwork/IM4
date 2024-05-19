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

@objc enum PresenceShow: Int {
    case Online, Away, Chat, Dnd, Xa
}

@objc class PresenceStatus: NSObject {
    @objc var type: String?
    @objc var status: String?
    @objc var show: String?

    @objc init(type: String?, status: String?, show: String?) {
        self.type = type
        self.status = status
        self.show = show
        super.init()
    }
    
    // convert the show string to PresenceShow
    @objc func presenceShowValue() -> PresenceShow {
        switch self.show {
        case "away": return PresenceShow.Away
        case "chat": return PresenceShow.Chat
        case "dnd":  return PresenceShow.Dnd
        case "xa":   return PresenceShow.Xa
        default: return PresenceShow.Online
        }
    }
    
    @objc func presenceShowUIString(template: UITemplate) -> String {
        switch self.show {
        case "away": return template.xmppPresenceAway()
        case "chat": return template.xmppPresenceChat()
        case "dnd":  return template.xmppPresenceDnd()
        case "xa":   return template.xmppPresenceXA()
        default: return ""
        }
    }
}

@objc class Presence: NSObject {
    @objc var statusMap: NSMutableDictionary
    @objc var lastStatus: PresenceStatus?
    
    @objc override init() {
        self.statusMap = NSMutableDictionary()
        super.init()
    }
    
    @objc func updateStatus(from: String, status: PresenceStatus) {
        self.lastStatus = status
        self.statusMap[from] = status
    }
    
    @objc func presenceStatus(resource: String) -> PresenceStatus? {
        return statusMap[resource] as! PresenceStatus?
    }
    
    // get the most relevant presence status
    // priority on case of multiple connections:
    // chat
    // online (no show element available)
    // away, dnd or xa
    @objc func getRelevantPresenceStatus() -> PresenceStatus? {
        var lastPresenceStatus = lastStatus
        for(_, value) in statusMap {
            let presence = value as! PresenceStatus
            if presence.show != nil {
                if presence.presenceShowValue() == PresenceShow.Chat {
                    return presence
                }
            } else {
                // at least one connection is online without away msg
                if let ps = lastPresenceStatus {
                    if ps.presenceShowValue() != PresenceShow.Online {
                        lastPresenceStatus = presence
                    }
                } else {
                    lastPresenceStatus = presence
                }
            }
        }
        
        return lastPresenceStatus
    }
}
