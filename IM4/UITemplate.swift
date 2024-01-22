//
//  UITemplate.swift
//  IM4
//
//  Created by Olaf Wintermann on 20.01.24.
//

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
    
    @objc func otrGoneSecure() -> String {
        return dict["otr.gonesecure"] as? String ?? "otr: gone secure"
    }

    @objc func otrGoneInsecure() -> String {
        return dict["otr.goneinsecure"] as? String ?? "otr: gone insecure"
    }

    @objc func otrDisabled() -> String {
        return dict["otr.disabled"] as? String ?? "otr disabled"
    }

    @objc func otrSecure() -> String {
        return dict["otr.secure"] as? String ?? "🔒"
    }

    @objc func otrInsecure() -> String {
        return dict["otr.unsecure"] as? String ?? ""
    }

    @objc func chatStateComposing() -> String {
        return dict["chatstate.composing"] as? String ?? "composing"
    }

    @objc func chatStatePaused() -> String {
        return dict["chatstate.paused"] as? String ?? "paused"
    }

    @objc func chatStateInactive() -> String {
        return dict["chatstate.inactive"] as? String ?? "inactive"
    }

    @objc func chatStateGone() -> String {
        return dict["chatstate.gone"] as? String ?? "gone"
    }

    @objc func msgInPrefixFormat() -> String {
        return dict["msg.in.format"] as? String ?? "< (%t) %a: "
    }

    @objc func msgOutPrefixFormat() -> String {
        return dict["msg.out.format"] as? String ?? "> (%t) %a: "
    }
    
    @objc func htmlMsgInFormat() -> String? {
        return dict["msg.htmlin.format"] as? String;
    }
    
    @objc func htmlMsgOutFormat() -> String? {
        return dict["msg.htmlout.format"] as? String;
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
