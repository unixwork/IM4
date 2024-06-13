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
    @objc var presence: String?
    @objc var status: String?
    @objc var unread: Int
    @objc var contacts: NSMutableArray?
    
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
    
    @objc(addContact:) func addContact(contact: Contact) {
        if let contacts = self.contacts {
            contacts.add(contact)
        }
    }
    
    @objc(displayName:) func displayName(tpl: UITemplate?) -> String {
        if contacts != nil {
            return name
        } else {
            var statusIcon = ""
            if let p = presence {
                statusIcon = p
            } else {
                if let tpl = tpl {
                    statusIcon = tpl.xmppPresenceIconOffline()
                }
            }
            
            var unreadNotification = ""
            if unread != 0 {
                unreadNotification = "*"
            }
            
            if let st = self.status {
                return String(format: "%@ %@%@ (%@)", statusIcon, name, unreadNotification, st)
            } else {
                return String(format: "%@ %@%@", statusIcon, name, unreadNotification)
            }
        }
    }
}
