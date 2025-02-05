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
import PixelKit

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

protocol RecentActivityFavoritesHandling: AnyObject {
    func getBookmark(for url: URL) -> Bookmark?
    func getFavorite(for url: URL) -> Bookmark?
    func markAsFavorite(_ bookmark: Bookmark)
    func unmarkAsFavorite(_ bookmark: Bookmark)
    func addNewFavorite(for url: URL)
}

extension LocalBookmarkManager: RecentActivityFavoritesHandling {

    func getFavorite(for url: URL) -> Bookmark? {
        guard let favorite = getBookmark(for: url), favorite.isFavorite else {
            return nil
        }
        return favorite
    }

    func markAsFavorite(_ bookmark: Bookmark) {
        guard !bookmark.isFavorite else {
            return
        }
        bookmark.isFavorite = true
        update(bookmark: bookmark)
    }

    func unmarkAsFavorite(_ bookmark: Bookmark) {
        guard bookmark.isFavorite else {
            return
        }
        bookmark.isFavorite = false
        update(bookmark: bookmark)
    }

    func addNewFavorite(for url: URL) {
        makeBookmark(for: url, title: url.host?.droppingWwwPrefix() ?? url.absoluteString, isFavorite: true)
    }
}

protocol RecentActivityItemBurning: AnyObject {
    @MainActor func burn(_ url: URL, burningDidComplete: @escaping () -> Void) async -> Bool
}

final class RecentActivityItemBurner: RecentActivityItemBurning {

    let tld: TLD
    let fire: () async -> Fire
    let fireproofStatusProvider: URLFireproofStatusProviding

    init(
        fireproofStatusProvider: URLFireproofStatusProviding = FireproofDomains.shared,
        tld: TLD = ContentBlocking.shared.tld,
        fire: (() async -> Fire)? = nil
    ) {
        self.fireproofStatusProvider = fireproofStatusProvider
        self.tld = tld
        self.fire = fire ?? { @MainActor in FireCoordinator.fireViewModel.fire }
    }

    @MainActor func burn(_ url: URL, burningDidComplete: @escaping () -> Void) async -> Bool {
        guard let domain = url.host?.droppingWwwPrefix() else {
            return false
        }
        guard await confirmBurningFireproofDomainIfNeeded(url) else {
            return false
        }
        let domains = Set([domain]).convertedToETLDPlus1(tld: tld)

        // This only starts burning and returns immediately (the await here is to retrieve Fire instance).
        // completion is called when burning completes.
        await fire().burnEntity(entity: .none(selectedDomains: domains), completion: burningDidComplete)

        return true
    }

    @MainActor
    func confirmBurningFireproofDomainIfNeeded(_ url: URL) async -> Bool {
        if fireproofStatusProvider.isDomainFireproof(forURL: url) {
            guard case .OK = await NSAlert.burnFireproofSiteAlert().runModal() else {
                return false
            }
        }
        return true
    }
}

final class DefaultRecentActivityActionsHandler: RecentActivityActionsHandling {

    let favoritesHandler: RecentActivityFavoritesHandling
    let burner: RecentActivityItemBurning
    let burnDidCompletePublisher: AnyPublisher<Void, Never>
    private let burnDidCompleteSubject = PassthroughSubject<Void, Never>()

    init(
        favoritesHandler: RecentActivityFavoritesHandling = LocalBookmarkManager.shared,
        burner: RecentActivityItemBurning = RecentActivityItemBurner()
    ) {
        self.favoritesHandler = favoritesHandler
        self.burner = burner
        self.burnDidCompletePublisher = burnDidCompleteSubject.eraseToAnyPublisher()
    }

    @MainActor
    func addFavorite(_ url: URL) {
        if let bookmark = favoritesHandler.getBookmark(for: url) {
            favoritesHandler.markAsFavorite(bookmark)
        } else {
            favoritesHandler.addNewFavorite(for: url)
        }
    }

    @MainActor
    func removeFavorite(_ url: URL) {
        guard let favorite = favoritesHandler.getFavorite(for: url) else {
            return
        }
        favoritesHandler.unmarkAsFavorite(favorite)
    }

    @MainActor
    func confirmBurn(_ url: URL) async -> Bool {
        await burner.burn(url) { [weak self] in
            self?.burnDidCompleteSubject.send()
        }
    }

    @MainActor
    func open(_ url: URL, target: LinkOpenTarget) {
        guard let tabCollectionViewModel else {
            return
        }

        PixelKit.fire(NewTabPagePixel.privacyFeedHistoryLinkOpened, frequency: .dailyAndCount)

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
    private var tabCollectionViewModel: TabCollectionViewModel? {
        WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel
    }
}
