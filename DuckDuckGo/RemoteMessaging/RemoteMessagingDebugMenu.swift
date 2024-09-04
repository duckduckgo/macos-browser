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
import AppKitExtensions
import BrowserServicesKit

final class RemoteMessagingDebugMenu: NSMenu {

    struct MessageModel: CustomStringConvertible {
        let id: String
        let shown: String
        let status: String

        init(message: RemoteMessageManagedObject) {
            self.id = message.id ?? "?"
            self.shown = message.shown ? "shown" : "not shown"
            self.status = Self.statusString(for: message.status)
        }

        var description: String {
            "ID: \(id) | \(shown) | \(status)"
        }

        /// This should be kept in sync with `RemoteMessageStatus` private enum from BSK
        private static func statusString(for status: NSNumber?) -> String {
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

        guard NSApplication.runType.requiresEnvironment, NSApp.delegateTyped.remoteMessagingClient.isRemoteMessagingDatabaseLoaded else {
            return
        }

        let database = NSApp.delegateTyped.remoteMessagingClient.database
        let context = database.makeContext(concurrencyType: .privateQueueConcurrencyType)
        let fetchRequest = RemoteMessageManagedObject.fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false

        var messageModels: [MessageModel] = []

        context.performAndWait {
            let messages = (try? context.fetch(fetchRequest)) ?? []
            for message in messages {
                messageModels.append(MessageModel(message: message))
            }
        }

        let headerItem = NSMenuItem(title: "\(messageModels.count) Message(s) in database:")
        headerItem.isEnabled = false

        addItem(NSMenuItem.separator())
        addItem(headerItem)

        for message in messageModels {
            let item = NSMenuItem(title: message.description)
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

}
