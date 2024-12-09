//
//  Contact.swift
//  IM4
//
//  Created by Olaf Wintermann on 13.06.24.
//

import Cocoa

@objc class Contact: NSObject {
    @objc var name: String
    @objc var xid: String?
    @objc var presence: PresenceStatus?
    @objc var unread: Int
    @objc var contacts: NSMutableArray?
    @objc var subscription: String?
    
    @objc(initContact:xid:) init(name: String, xid: String?) {
        self.name = name
        self.xid = xid
        self.unread = 0
        super.init()
    }

    @objc(initGroup:) init(name: String) {
        self.name = name
        self.unread = 0
        self.contacts = NSMutableArray()
        super.init()
    }
    
    @objc func addContact(_ contact: Contact) {
        if let contacts = self.contacts {
            contacts.add(contact)
        }
    }
    
    @objc func displayName(_ tpl: UITemplate) -> String {
        if contacts != nil {
            return name
        } else {
            var statusIcon = ""
            if let ps = presence {
                statusIcon = ps.presenceShowIconUIString(template: tpl)
            } else {
                if let sub = subscription {
                    if sub == "none" || sub == "from" {
                        statusIcon = tpl.xmppUnsubscribed()
                    } else {
                        statusIcon = tpl.xmppPresenceIconOffline()
                    }
                } else {
                    statusIcon = tpl.xmppPresenceIconOffline()
                }
                
            }
            
            var status: String?
            if let ps = presence {
                status = ps.status
            }
            
            var unreadNotification = ""
            if unread != 0 {
                unreadNotification = "*"
            }
            
            if let st = status {
                return String(format: "%@ %@%@ (%@)", statusIcon, name, unreadNotification, st)
            } else {
                return String(format: "%@ %@%@", statusIcon, name, unreadNotification)
            }
        }
    }
    
    @objc func tooltip() -> String {
        var x = ""
        var s = ""
        if let xid = xid {
            x = String(format: "%@ ", xid)
        }
        if let subscription = subscription {
            s = String(format: "subscription: %@", subscription)
        }
        
        return String(format: "%@%@", x, s)
    }
}
