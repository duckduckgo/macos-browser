//
//  NSMenuExtension.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

extension NSMenu {

    enum MenuItemTag: Int {
        case history = 4
        case back = 40
        case forward = 41
        case reopenLastClosedTab = 43
        case help = 6
        case helpSeparator = 61
        case sendFeedback = 62
    }

    var backMenuItem: NSMenuItem? {
        return item(withTag: MenuItemTag.history.rawValue)?.submenu?.item(withTag: MenuItemTag.back.rawValue)
    }

    var forwardMenuItem: NSMenuItem? {
        return item(withTag: MenuItemTag.history.rawValue)?.submenu?.item(withTag: MenuItemTag.forward.rawValue)
    }

    var reopenLastClosedTabMenuItem: NSMenuItem? {
        return item(withTag: MenuItemTag.history.rawValue)?.submenu?.item(withTag: MenuItemTag.reopenLastClosedTab.rawValue)
    }

    var helpMenuItem: NSMenuItem? {
        return item(withTag: MenuItemTag.help.rawValue)
    }

    var helpSeparatorMenuItem: NSMenuItem? {
        helpMenuItem?.submenu?.item(withTag: MenuItemTag.helpSeparator.rawValue)
    }

    var sendFeedbackMenuItem: NSMenuItem? {
        helpMenuItem?.submenu?.item(withTag: MenuItemTag.sendFeedback.rawValue)
    }

}
