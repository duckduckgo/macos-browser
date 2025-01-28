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

import Combine
import Common
import Foundation
import NewTabPage

protocol URLFireproofStatusProviding: AnyObject {
    func isDomainFireproof(forURL url: URL) -> Bool
}

extension FireproofDomains: URLFireproofStatusProviding {
    func isDomainFireproof(forURL url: URL) -> Bool {
        guard let domain = url.host?.droppingWwwPrefix() else {
            return false
        }
        return isFireproof(fireproofDomain: domain)
    }
}

final class DefaultRecentActivityActionsHandler: RecentActivityActionsHandling {

    let bookmarkManager: BookmarkManager
    let fireproofStatusProvider: URLFireproofStatusProviding
    let fireViewModel: () async -> FireViewModel
    let tld: TLD
    let burnDidCompletePublisher: AnyPublisher<Void, Never>
    private let burnDidCompleteSubject = PassthroughSubject<Void, Never>()

    init(
        bookmarkManager: BookmarkManager = LocalBookmarkManager.shared,
        fireproofStatusProvider: URLFireproofStatusProviding = FireproofDomains.shared,
        fireViewModel: (() async -> (FireViewModel))? = nil,
        tld: TLD = ContentBlocking.shared.tld
    ) {
        self.bookmarkManager = bookmarkManager
        self.fireproofStatusProvider = fireproofStatusProvider
        self.fireViewModel = fireViewModel ?? { @MainActor in FireCoordinator.fireViewModel }
        self.tld = tld
        self.burnDidCompletePublisher = burnDidCompleteSubject.eraseToAnyPublisher()
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
        guard let domain = url.host?.droppingWwwPrefix() else {
            return false
        }
        if fireproofStatusProvider.isDomainFireproof(forURL: url) {
            guard case .OK = await NSAlert.burnFireproofSiteAlert().runModal() else {
                return false
            }
        }
        let domains = Set([domain]).convertedToETLDPlus1(tld: tld)
        let fireViewModel = await fireViewModel()
        fireViewModel.fire.burnEntity(entity: .none(selectedDomains: domains)) { [weak self] in
            self?.burnDidCompleteSubject.send()
        }
        return true
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
