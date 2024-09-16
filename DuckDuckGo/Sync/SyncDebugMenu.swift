//
//  SyncDebugMenu.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import DDGSync
import Bookmarks

final class SyncDebugMenu: NSMenu {

    private let environmentMenu = NSMenu()

    init() {
        super.init(title: "")

        buildItems {
            NSMenuItem(title: "Environment")
                .submenu(environmentMenu)
                .withAccessibilityIdentifier("SyncDebugMenu.environment")
            NSMenuItem(title: "Reset Favicons Fetcher Onboarding Dialog", action: #selector(resetFaviconsFetcherOnboardingDialog))
                .targetting(self)
            NSMenuItem(title: "Populate Stub objects", action: #selector(createStubsForDebug))
                .targetting(self)
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update() {
        populateEnvironmentMenu()
    }

    private func populateEnvironmentMenu() {
        environmentMenu.removeAllItems()

        guard let syncService = NSApp.delegateTyped.syncService else {
            return
        }

        let currentEnvironment = syncService.serverEnvironment
        let anotherEnvironment: ServerEnvironment = syncService.serverEnvironment == .development ? .production : .development

        let statusMenuItem = NSMenuItem(title: "Current: \(currentEnvironment.description)", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        environmentMenu.addItem(statusMenuItem.withAccessibilityIdentifier("SyncDebugMenu.currentEnvironment"))

        let toggleMenuItem = NSMenuItem(
            title: "Switch to \(anotherEnvironment.description)",
            action: #selector(switchSyncEnvironment),
            target: self,
            representedObject: anotherEnvironment)
        environmentMenu.addItem(toggleMenuItem.withAccessibilityIdentifier("SyncDebugMenu.switchEnvironment"))
    }

    @objc func switchSyncEnvironment(_ sender: NSMenuItem) {
#if DEBUG || REVIEW
        guard let syncService = NSApp.delegateTyped.syncService,
              let environment = sender.representedObject as? ServerEnvironment
        else {
            return
        }

        syncService.updateServerEnvironment(environment)
        UserDefaults.standard.set(environment.description, forKey: UserDefaultsWrapper<String>.Key.syncEnvironment.rawValue)
#endif
    }

    @objc func createStubsForDebug() {
#if DEBUG || REVIEW
        let db = BookmarkDatabase.shared

        let context = db.db.makeContext(concurrencyType: .privateQueueConcurrencyType)

        context.performAndWait {
            let root = BookmarkUtils.fetchRootFolder(context)!
            let favorites = BookmarkUtils.fetchFavoritesFolders(for: .displayNative(.desktop), in: context)

            let nonStub1 = BookmarkEntity.makeBookmark(title: "Non stub", url: "url", parent: root, context: context)
            nonStub1.addToFavorites(folders: favorites)

            let stub1 = BookmarkEntity.makeBookmark(title: "Stub", url: "", parent: root, context: context)
            stub1.isStub = true
            stub1.addToFavorites(folders: favorites)

            let emptyStub = BookmarkEntity.makeBookmark(title: "", url: "", parent: root, context: context)
            emptyStub.isStub = true
            emptyStub.title = nil
            emptyStub.url = nil
            emptyStub.addToFavorites(folders: favorites)

            let nonStub2 = BookmarkEntity.makeBookmark(title: "Non stub 2", url: "url", parent: root, context: context)
            nonStub2.addToFavorites(folders: favorites)

            let stub2 = BookmarkEntity.makeBookmark(title: "Stub", url: "", parent: root, context: context)
            stub2.isStub = true
            stub2.addToFavorites(folders: favorites)

            let stub3 = BookmarkEntity.makeBookmark(title: "Stub", url: "", parent: root, context: context)
            stub3.isStub = true
            stub3.addToFavorites(folders: favorites)

            let nonStub3 = BookmarkEntity.makeBookmark(title: "Non stub 3", url: "url", parent: root, context: context)
            nonStub3.addToFavorites(folders: favorites)

            try? context.save()
        }
#endif
    }

    @objc func resetFaviconsFetcherOnboardingDialog(_ sender: NSMenuItem) {
        UserDefaults.standard.set(false, forKey: UserDefaultsWrapper<String>.Key.syncDidPresentFaviconsFetcherOnboarding.rawValue)
    }
}
