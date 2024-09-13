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
import OSLog

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

        menu.addItem(NSMenuItem(title: "Set Freemium DBP Activated State TRUE", action: #selector(setFreemiumDBPActivateStateTrue), target: self))
        menu.addItem(NSMenuItem(title: "Set Freemium DBP Activated State FALSE", action: #selector(setFreemiumDBPActivateStateFalse), target: self))
        menu.addItem(NSMenuItem(title: "Set Freemium DBP First Profile Saved Timestamp NIL", action: #selector(setFirstProfileSavedTimestampNil), target: self))
        menu.addItem(NSMenuItem(title: "Set Freemium DBP Did Post First Profile Saved FALSE", action: #selector(setDidPostFirstProfileSavedNotificationFalse), target: self))
        menu.addItem(NSMenuItem(title: "Set Freemium DBP Did Post Results FALSE", action: #selector(setDidPostResultsNotificationFalse), target: self))
        menu.addItem(NSMenuItem(title: "Trigger Engagement UX Results", action: #selector(triggerEngagementUXResults), target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Set New Tab Promotion Did Dismiss FALSE", action: #selector(setNewTabPromotionDidDismissFalse), target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Log all state", action: #selector(logAllState), target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "RESET ALL STATE", action: #selector(resetAllState), target: self))

        return menu
    }

    @objc
    func setFreemiumDBPActivateStateTrue() {
        DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).didActivate = true
    }

    @objc
    func setFreemiumDBPActivateStateFalse() {
        DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).didActivate = false
    }

    @objc
    func setFirstProfileSavedTimestampNil() {
        DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).firstProfileSavedTimestamp = nil
    }

    @objc
    func setDidPostFirstProfileSavedNotificationFalse() {
        DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).didPostFirstProfileSavedNotification = false
    }

    @objc
    func setDidPostResultsNotificationFalse() {
        DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).didPostResultsNotification = false
    }

    @objc
    func triggerEngagementUXResults() {
        NotificationCenter.default.post(name: .freemiumDBPResultPollingComplete, object: nil)
    }

    @objc
    func setFirstScanResultsNil() {
        DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).firstScanResults = nil
    }

    @objc
    func setNewTabPromotionDidDismissFalse() {
        DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).didDismissHomePagePromotion = false
    }

    @objc
    func logAllState() {

        Logger.freemiumDBP.debug("FREEMIUM DBP: DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).didActivate \(DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).didActivate)")
        Logger.freemiumDBP.debug("FREEMIUM DBP: DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).firstProfileSavedTimestamp \(DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).firstProfileSavedTimestamp ?? "Nil")")
        Logger.freemiumDBP.debug("FREEMIUM DBP: DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).didPostFirstProfileSavedNotification \(DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).didPostFirstProfileSavedNotification)")
        Logger.freemiumDBP.debug("FREEMIUM DBP: DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).didPostResultsNotification \(DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).didPostResultsNotification)")
        if let results = DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).firstScanResults {
            Logger.freemiumDBP.debug("FREEMIUM DBP: DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).firstScanResults \(results.matchesCount) - \(results.brokerCount)")
        } else {
            Logger.freemiumDBP.debug("FREEMIUM DBP: DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).firstScanResults Nil")
        }
        Logger.freemiumDBP.debug("FREEMIUM DBP: DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).didDismissHomePagePromotion \(DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).didDismissHomePagePromotion)")
    }

    @objc
    func resetAllState() {
        DefaultFreemiumDBPUserStateManager(userDefaults: .dbp).resetAllState()
    }
}
