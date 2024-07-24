//
//  RemoteMessagingDebugMenu.swift
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

import AppKit
import RemoteMessaging

final class RemoteMessagingDebugMenu: NSMenu {

    init() {
        super.init(title: "")

        buildItems {
            NSMenuItem(title: "Reset Remote Messages", action: #selector(AppDelegate.resetRemoteMessages))
                .withAccessibilityIdentifier("RemoteMessagingDebugMenu.resetRemoteMessages")
            NSMenuItem(title: "Refresh Config", action: #selector(fetchRemoteMessagesConfig), target: self)
                .withAccessibilityIdentifier("RemoteMessagingDebugMenu.fetchRemoteMessagesConfig")
            NSMenuItem(title: "View Config", action: #selector(openRemoteMessagesConfig), target: self)
                .withAccessibilityIdentifier("RemoteMessagingDebugMenu.openRemoteMessagesConfig")
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update() {
        populateMessages()
    }

    private func populateMessages() {
        (3..<self.numberOfItems).forEach { _ in
            removeItem(at: 3)
        }

        let database = NSApp.delegateTyped.remoteMessagingClient.database
        let context = database.makeContext(concurrencyType: .mainQueueConcurrencyType)
        let fetchRequest = RemoteMessageManagedObject.fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        let messages = (try? context.fetch(fetchRequest)) ?? []

        let headerItem = NSMenuItem(title: "\(messages.count) Message(s) in database:")
        headerItem.isEnabled = false

        addItem(NSMenuItem.separator())
        addItem(headerItem)

        for message in messages {
            let item = NSMenuItem(title: "ID: \(message.id ?? "?") | \(message.shown ? "shown" : "not shown") | \(statusString(for: message.status))")
            item.isEnabled = false
            addItem(item)
        }
    }

    @objc func fetchRemoteMessagesConfig() {
        NSApp.delegateTyped.remoteMessagingClient.refreshRemoteMessages()
    }

    @objc func openRemoteMessagesConfig() {
        Task { @MainActor in
            WindowControllersManager.shared.showTab(with: .contentFromURL(RemoteMessagingClient.Constants.endpoint, source: .appOpenUrl))
        }
    }

    /// This should be kept in sync with `RemoteMessageStatus` private enum from BSK
    private func statusString(for status: NSNumber?) -> String {
        switch status?.int16Value {
        case 0:
            return "scheduled"
        case 1:
            return "dismissed"
        case 2:
            return "done"
        default:
            return "unknown"
        }
    }
}
