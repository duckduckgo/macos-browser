//
//  FreemiumDebugMenu.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Foundation
import Freemium

final class FreemiumDebugMenu: NSMenuItem {

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public init() {
        super.init(title: "Freemium", action: nil, keyEquivalent: "")
        self.submenu = makeSubmenu()
    }

    private func makeSubmenu() -> NSMenu {
        let menu = NSMenu(title: "")

        menu.addItem(NSMenuItem(title: "Set Freemium PIR Onboarded State TRUE", action: #selector(setFreemiumPIROnboardStateTrue), target: self))
        menu.addItem(NSMenuItem(title: "Set Freemium PIR Onboarded State FALSE", action: #selector(setFreemiumPIROnboardStateFalse), target: self))
        menu.addItem(NSMenuItem(title: "Set Freemium PIR First Profile Saved Timestamp NIL", action: #selector(setFirstProfileSavedTimestampNil), target: self))
        menu.addItem(NSMenuItem(title: "Set Freemium DBP Did Post First Profile Saved FALSE", action: #selector(setDidPostFirstProfileSavedNotificationFalse), target: self))
        menu.addItem(.separator())

        return menu
    }

    @objc
    func setFreemiumPIROnboardStateTrue() {
        DefaultFreemiumPIRUserStateManager(userDefaults: .dbp).didOnboard = true
    }

    @objc
    func setFreemiumPIROnboardStateFalse() {
        DefaultFreemiumPIRUserStateManager(userDefaults: .dbp).didOnboard = false
    }

    @objc
    func setFirstProfileSavedTimestampNil() {
        DefaultFreemiumPIRUserStateManager(userDefaults: .dbp).firstProfileSavedTimestamp = nil
    }

    @objc
    func setDidPostFirstProfileSavedNotificationFalse() {
        DefaultFreemiumPIRUserStateManager(userDefaults: .dbp).didPostFirstProfileSavedNotification = false
    }
}
