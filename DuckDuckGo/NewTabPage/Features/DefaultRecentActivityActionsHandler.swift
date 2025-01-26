//
//  DefaultRecentActivityActionsHandler.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import Common
import Foundation
import NewTabPage

final class DefaultRecentActivityActionsHandler: RecentActivityActionsHandling {

    let bookmarkManager: BookmarkManager
    let fireproofDomains: FireproofDomains
    let fire: () async -> Fire
    let tld: TLD

    init(
        bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
        fireproofDomains: FireproofDomains = FireproofDomains.shared,
        fire: (() async -> (Fire))? = nil,
        tld: TLD = ContentBlocking.shared.tld
    ) {
        self.bookmarkManager = bookmarkManager
        self.fireproofDomains = fireproofDomains
        self.fire = fire ?? { @MainActor in FireCoordinator.fireViewModel.fire }
        self.tld = tld
    }

    @MainActor
    func addFavorite(_ url: URL) {
        if let bookmark = bookmarkManager.getBookmark(for: url) {
            guard !bookmark.isFavorite else {
                return
            }
            bookmark.isFavorite = true
            bookmarkManager.update(bookmark: bookmark)
        } else {
            bookmarkManager.makeBookmark(for: url, title: url.host?.droppingWwwPrefix() ?? url.absoluteString, isFavorite: true)
        }
    }

    @MainActor
    func removeFavorite(_ url: URL) {
        guard let favorite = bookmarkManager.getBookmark(for: url), favorite.isFavorite else {
            return
        }
        favorite.isFavorite = false
        bookmarkManager.update(bookmark: favorite)
    }

    @MainActor
    func confirmBurn(_ url: URL) async -> Bool {
        guard let domain = url.host?.droppingWwwPrefix(), fireproofDomains.isFireproof(fireproofDomain: domain) else {
            return false
        }
        guard case .OK = await NSAlert.burnFireproofSiteAlert().runModal() else {
            return false
        }
        return true
    }

    @MainActor
    func burn(_ url: URL) async {
        guard let domain = url.host?.droppingWwwPrefix() else {
            return
        }
        let domains = Set([domain]).convertedToETLDPlus1(tld: tld)
        await fire().burnEntity(entity: .none(selectedDomains: domains))
    }

    @MainActor
    func open(_ url: URL, target: LinkOpenTarget) {
        guard let tabCollectionViewModel else {
            return
        }

        if target == .newWindow || NSApplication.shared.isCommandPressed && NSApplication.shared.isOptionPressed {
            WindowsManager.openNewWindow(with: url, source: .bookmark, isBurner: tabCollectionViewModel.isBurner)
        } else if target == .newTab || NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
            tabCollectionViewModel.insertOrAppendNewTab(.contentFromURL(url, source: .bookmark), selected: true)
        } else if NSApplication.shared.isCommandPressed {
            tabCollectionViewModel.insertOrAppendNewTab(.contentFromURL(url, source: .bookmark), selected: false)
        } else {
            tabCollectionViewModel.selectedTabViewModel?.tab.setContent(.contentFromURL(url, source: .bookmark))
        }
    }

    @MainActor
    private var window: NSWindow? {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.view.window
    }

    @MainActor
    private var tabCollectionViewModel: TabCollectionViewModel? {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel
    }
}
