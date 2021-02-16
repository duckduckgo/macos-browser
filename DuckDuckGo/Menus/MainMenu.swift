//
//  MainMenu.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Cocoa
import os.log

class MainMenu: NSMenu {

    @IBOutlet weak var printSeparatorItem: NSMenuItem?
    @IBOutlet weak var printMenuItem: NSMenuItem?

    required init(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }

    enum Tag: Int {
        case history = 4
        case back = 40
        case forward = 41
        case reopenLastClosedTab = 43
        case help = 6
        case helpSeparator = 61
        case sendFeedback = 62
    }

    var backMenuItem: NSMenuItem? {
        return item(withTag: Tag.history.rawValue)?.submenu?.item(withTag: Tag.back.rawValue)
    }

    var forwardMenuItem: NSMenuItem? {
        return item(withTag: Tag.history.rawValue)?.submenu?.item(withTag: Tag.forward.rawValue)
    }

    var reopenLastClosedTabMenuItem: NSMenuItem? {
        return item(withTag: Tag.history.rawValue)?.submenu?.item(withTag: Tag.reopenLastClosedTab.rawValue)
    }

    var helpMenuItem: NSMenuItem? {
        return item(withTag: Tag.help.rawValue)
    }

    var helpSeparatorMenuItem: NSMenuItem? {
        helpMenuItem?.submenu?.item(withTag: Tag.helpSeparator.rawValue)
    }

    var sendFeedbackMenuItem: NSMenuItem? {
        helpMenuItem?.submenu?.item(withTag: Tag.sendFeedback.rawValue)
    }

    private func setup() {

#if !FEEDBACK

    guard let helpMenuItemSubmenu = helpMenuItem?.submenu,
          let helpSeparatorMenuItem = helpSeparatorMenuItem,
          let sendFeedbackMenuItem = sendFeedbackMenuItem else {
        os_log("MainMenuManager: Failed to setup main menu", type: .error)
        return
    }

    helpMenuItemSubmenu.removeItem(helpSeparatorMenuItem)
    helpMenuItemSubmenu.removeItem(sendFeedbackMenuItem)

#endif

    }

    override func update() {
        super.update()

        if #available(macOS 11, *) {
            // no-op
        } else {
            printMenuItem?.removeFromParent()
            printSeparatorItem?.removeFromParent()
        }

    }

}

extension NSMenuItem {

    func removeFromParent() {
        parent?.submenu?.removeItem(self)
    }

}
