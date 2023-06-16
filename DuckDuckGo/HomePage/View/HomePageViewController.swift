//
//  HomePageViewController.swift
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
import Combine
import DependencyInjection
import SwiftUI

#if swift(>=5.9)
@Injectable
#endif
@MainActor
final class HomePageViewController: NSViewController, Injectable {

    let dependencies: DependencyStorage

    @Injected
    var windowManager: WindowManagerProtocol
    @Injected
    var fireViewModel: FireViewModel

    private let tabCollectionViewModel: TabCollectionViewModel
    private var bookmarkManager: BookmarkManager
    private let historyCoordinating: HistoryCoordinating

    private weak var host: NSView?

    var favoritesModel: HomePage.Models.FavoritesModel!
    var defaultBrowserModel: HomePage.Models.DefaultBrowserModel!
    var recentlyVisitedModel: HomePage.Models.RecentlyVisitedModel!
    var cancellables = Set<AnyCancellable>()

    @UserDefaultsWrapper(key: .defaultBrowserDismissed, defaultValue: false)
    var defaultBrowserDismissed: Bool

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    init?(coder: NSCoder,
          tabCollectionViewModel: TabCollectionViewModel,
          bookmarkManager: BookmarkManager,
          historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
          dependencyProvider: DependencyProvider) {
        self.dependencies = .init(dependencyProvider)

        self.tabCollectionViewModel = tabCollectionViewModel
        self.bookmarkManager = bookmarkManager
        self.historyCoordinating = historyCoordinating

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshModelsOnAppBecomingActive()

        favoritesModel = createFavoritesModel()
        defaultBrowserModel = createDefaultBrowserModel()
        recentlyVisitedModel = createRecentlyVisitedModel()

        refreshModels()

        let rootView = HomePage.Views.RootView(isBurner: tabCollectionViewModel.isBurner)
            .environmentObject(favoritesModel)
            .environmentObject(defaultBrowserModel)
            .environmentObject(recentlyVisitedModel)
            .onTapGesture { [weak self] in
                // Remove focus from the address bar if interacting with this view.
                self?.view.makeMeFirstResponder()
            }

        let host = NSHostingView(rootView: rootView)
        host.frame = view.frame
        view.addSubview(host)
        self.host = host

        subscribeToBookmarks()
        subscribeToBurningData()

        // Temporary pixel for first time user sees the new tab
        if Pixel.isNewUser {
            let repetition = Pixel.Event.Repetition(key: Pixel.Event.newTabInitial.name)
            if repetition == .initial {
                Pixel.fire(.newTabInitial)
            }
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        subscribeToHistory()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refreshModels()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        host?.frame = self.view.frame
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        historyCancellable = nil
    }

    func refreshModelsOnAppBecomingActive() {
        NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.refreshModels()
            }.store(in: &self.cancellables)
    }

    func refreshModels() {
        guard !NSApp.isRunningUnitTests else { return }

        refreshFavoritesModel()
        refreshRecentlyVisitedModel()
        refreshDefaultBrowserModel()
    }

    func createRecentlyVisitedModel() -> HomePage.Models.RecentlyVisitedModel {
        return .init(fire: fireViewModel.fire) { [weak self] url in
            self?.openUrl(url)
        }
    }

    func createDefaultBrowserModel() -> HomePage.Models.DefaultBrowserModel {
        return .init(isDefault: DefaultBrowserPreferences().isDefault, wasClosed: defaultBrowserDismissed, requestSetDefault: { [weak self] in
            let defaultBrowserPreferencesModel = DefaultBrowserPreferences()
            defaultBrowserPreferencesModel.becomeDefault { [weak self] isDefault in
                _ = defaultBrowserPreferencesModel
                self?.defaultBrowserModel.isDefault = isDefault
            }
        }, close: { [weak self] in
            self?.defaultBrowserDismissed = true
            withAnimation {
                self?.defaultBrowserModel.wasClosed = true
            }
        })
    }

    func createFavoritesModel() -> HomePage.Models.FavoritesModel {
        return .init(open: { [weak self] bookmark, target in
            guard let urlObject = bookmark.urlObject else { return }
            self?.openUrl(urlObject, target: target)
        }, removeFavorite: { [weak self] bookmark in
            bookmark.isFavorite = !bookmark.isFavorite
            self?.bookmarkManager.update(bookmark: bookmark)
        }, deleteBookmark: { [weak self] bookmark in
            self?.bookmarkManager.remove(bookmark: bookmark)
        }, addEdit: { [weak self] bookmark in
            self?.showAddEditController(for: bookmark)
        }, moveFavorite: { [weak self] (bookmark, index) in
            self?.bookmarkManager.moveFavorites(with: [bookmark.id], toIndex: index) { _ in }
        })
    }

    func refreshFavoritesModel() {
        favoritesModel.favorites = bookmarkManager.list?.favoriteBookmarks ?? []
    }

    func refreshRecentlyVisitedModel() {
        recentlyVisitedModel.refreshWithHistory(historyCoordinating.history ?? [])
    }

    func refreshDefaultBrowserModel() {
        let prefs = DefaultBrowserPreferences()
        if prefs.isDefault {
            defaultBrowserDismissed = false
        }

        defaultBrowserModel.isDefault = prefs.isDefault
        defaultBrowserModel.wasClosed = defaultBrowserDismissed
    }

    func subscribeToBookmarks() {
        bookmarkManager.listPublisher.receive(on: RunLoop.main).sink { [weak self] _ in
            withAnimation {
                self?.refreshFavoritesModel()
            }
        }.store(in: &cancellables)
    }

    private func openUrl(_ url: URL, target: HomePage.Models.FavoritesModel.OpenTarget? = nil) {
        if target == .newWindow || NSApplication.shared.isCommandPressed && NSApplication.shared.isOptionPressed {
            windowManager.openNewWindow(with: url, isBurner: tabCollectionViewModel.isBurner)
            return
        }

        if target == .newTab || NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
            tabCollectionViewModel.appendNewTab(with: .contentFromURL(url), selected: true)
            return
        }

        if NSApplication.shared.isCommandPressed {
            tabCollectionViewModel.appendNewTab(with: .contentFromURL(url), selected: false)
            return
        }

        tabCollectionViewModel.selectedTabViewModel?.tab.setContent(.contentFromURL(url))
    }

    private func showAddEditController(for bookmark: Bookmark? = nil) {
        // swiftlint:disable force_cast
        let windowController = NSStoryboard(name: "HomePage", bundle: .main).instantiateController(withIdentifier: "AddEditFavoriteWindowController") as! NSWindowController
        // swiftlint:enable force_cast

        guard let window = windowController.window as? AddEditFavoriteWindow else {
            assertionFailure("HomePageViewController: Failed to present AddEditFavoriteWindowController")
            return
        }

        guard let screen = window.screen else {
            assertionFailure("HomePageViewController: No screen")
            return
        }

        if let bookmark = bookmark {
            window.addEditFavoriteViewController.edit(bookmark: bookmark)
        }

        let windowFrame = NSRect(x: screen.frame.origin.x + screen.frame.size.width / 2.0 - AddEditFavoriteWindow.Size.width / 2.0,
                                 y: screen.frame.origin.y + screen.frame.size.height / 2.0 - AddEditFavoriteWindow.Size.height / 2.0,
                                 width: AddEditFavoriteWindow.Size.width,
                                 height: AddEditFavoriteWindow.Size.height)

        view.window?.addChildWindow(window, ordered: .above)
        window.setFrame(windowFrame, display: true)
        window.makeKey()
    }

    private var burningDataCancellable: AnyCancellable?
    private func subscribeToBurningData() {
        burningDataCancellable = fireViewModel.fire.$burningData
            .dropFirst()
            .sink { [weak self] burningData in
                if burningData == nil {
                    self?.refreshModels()
                }
            }
    }

    private var historyCancellable: AnyCancellable?
    private func subscribeToHistory() {
        historyCancellable = historyCoordinating.historyDictionaryPublisher.dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshModels()
            }
    }

}
