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

import BrowserServicesKit
import Cocoa
import Combine
import SwiftUI
import History
import PixelKit
import RemoteMessaging
import Freemium

@MainActor
final class HomePageViewController: NSViewController {

    private let tabCollectionViewModel: TabCollectionViewModel
    private var bookmarkManager: BookmarkManager
    private let historyCoordinating: HistoryCoordinating
    private let fireViewModel: FireViewModel
    private let onboardingViewModel: OnboardingViewModel
    private let freemiumDBPPromotionViewCoordinator: FreemiumDBPPromotionViewCoordinator

    private(set) lazy var faviconsFetcherOnboarding: FaviconsFetcherOnboarding? = {
        guard let syncService = NSApp.delegateTyped.syncService, let syncBookmarksAdapter = NSApp.delegateTyped.syncDataProviders?.bookmarksAdapter else {
            assertionFailure("SyncService and/or SyncBookmarksAdapter is nil")
            return nil
        }
        return .init(syncService: syncService, syncBookmarksAdapter: syncBookmarksAdapter)
    }()

    var favoritesModel: HomePage.Models.FavoritesModel!
    var defaultBrowserModel: HomePage.Models.DefaultBrowserModel!
    var recentlyVisitedModel: HomePage.Models.RecentlyVisitedModel!
    var featuresModel: HomePage.Models.ContinueSetUpModel!
    let settingsVisibilityModel = HomePage.Models.SettingsVisibilityModel()
    private(set) var addressBarModel: HomePage.Models.AddressBarModel!
    let accessibilityPreferences: AccessibilityPreferences
    let appearancePreferences: AppearancePreferences
    let defaultBrowserPreferences: DefaultBrowserPreferences
    let privacyConfigurationManager: PrivacyConfigurationManaging
    var cancellables = Set<AnyCancellable>()

    private var isShowingSearchBar: Bool = false

    @UserDefaultsWrapper(key: .defaultBrowserDismissed, defaultValue: false)
    var defaultBrowserDismissed: Bool

    required init?(coder: NSCoder) {
        fatalError("HomePageViewController: Bad initializer")
    }

    init(tabCollectionViewModel: TabCollectionViewModel,
         bookmarkManager: BookmarkManager,
         historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
         fireViewModel: FireViewModel? = nil,
         onboardingViewModel: OnboardingViewModel = OnboardingViewModel(),
         accessibilityPreferences: AccessibilityPreferences = AccessibilityPreferences.shared,
         appearancePreferences: AppearancePreferences = AppearancePreferences.shared,
         defaultBrowserPreferences: DefaultBrowserPreferences = DefaultBrowserPreferences.shared,
         freemiumDBPPromotionViewCoordinator: FreemiumDBPPromotionViewCoordinator,
         privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager) {

        self.tabCollectionViewModel = tabCollectionViewModel
        self.bookmarkManager = bookmarkManager
        self.historyCoordinating = historyCoordinating
        self.fireViewModel = fireViewModel ?? FireCoordinator.fireViewModel
        self.onboardingViewModel = onboardingViewModel
        self.accessibilityPreferences = accessibilityPreferences
        self.appearancePreferences = appearancePreferences
        self.defaultBrowserPreferences = defaultBrowserPreferences
        self.freemiumDBPPromotionViewCoordinator = freemiumDBPPromotionViewCoordinator
        self.privacyConfigurationManager = privacyConfigurationManager

        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        favoritesModel = createFavoritesModel()
        defaultBrowserModel = createDefaultBrowserModel()
        recentlyVisitedModel = createRecentlyVisitedModel()
        featuresModel = createFeatureModel()
        addressBarModel = createAddressBarModel()

        refreshModels()

        let rootView = HomePage.Views.RootView(isBurner: tabCollectionViewModel.isBurner, freemiumDBPPromotionViewCoordinator: freemiumDBPPromotionViewCoordinator)
            .environmentObject(favoritesModel)
            .environmentObject(defaultBrowserModel)
            .environmentObject(recentlyVisitedModel)
            .environmentObject(featuresModel)
            .environmentObject(Application.appDelegate.homePageSettingsModel)
            .environmentObject(accessibilityPreferences)
            .environmentObject(appearancePreferences)
            .environmentObject(Application.appDelegate.activeRemoteMessageModel)
            .environmentObject(settingsVisibilityModel)
            .environmentObject(addressBarModel)

        self.view = NSHostingView(rootView: rootView)
    }

    override func viewDidLoad() {
        refreshModelsOnAppBecomingActive()
        subscribeToBookmarks()
        subscribeToBurningData()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        if OnboardingViewModel.isOnboardingFinished && AppDelegate.isNewUser {
            PixelKit.fire(GeneralPixel.newTabInitial, frequency: .legacyInitial)
        }
        subscribeToHistory()
        addressBarModel.setUpExperimentIfNeeded()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refreshModels()

        showSettingsOnboardingIfNeeded()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        historyCancellable = nil

        presentedViewControllers?.forEach { $0.dismiss() }
    }

    func refreshModelsOnAppBecomingActive() {
        NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.refreshModels()
            }.store(in: &self.cancellables)
    }

    func refreshModels() {
        guard NSApp.runType.requiresEnvironment else { return }

        refreshFavoritesModel()
        refreshRecentlyVisitedModel()
        refreshDefaultBrowserModel()
        refreshContinueSetUpModel()
    }

    func createRecentlyVisitedModel() -> HomePage.Models.RecentlyVisitedModel {
        return .init { [weak self] url in
            PixelKit.fire(NewTabPagePixel.privacyFeedHistoryLinkOpened, frequency: .dailyAndCount)
            self?.openUrl(url)
        }
    }

    func createFeatureModel() -> HomePage.Models.ContinueSetUpModel {
        return HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: SystemDefaultBrowserProvider(),
            dockCustomizer: DockCustomizer(),
            dataImportProvider: BookmarksAndPasswordsImportStatusProvider(),
            tabOpener: TabCollectionViewModelTabOpener(tabCollectionViewModel: tabCollectionViewModel),
            duckPlayerPreferences: DuckPlayerPreferencesUserDefaultsPersistor()
        )
    }

    func createDefaultBrowserModel() -> HomePage.Models.DefaultBrowserModel {
        return .init(isDefault: DefaultBrowserPreferences.shared.isDefault, wasClosed: defaultBrowserDismissed, requestSetDefault: { [weak self] in
            PixelKit.fire(GeneralPixel.defaultRequestedFromHomepage)
            let defaultBrowserPreferencesModel = DefaultBrowserPreferences.shared
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
            PixelExperiment.fireOnboardingBookmarkUsed5to7Pixel()
        }, removeFavorite: { [weak self] bookmark in
            bookmark.isFavorite = !bookmark.isFavorite
            self?.bookmarkManager.update(bookmark: bookmark)
        }, deleteBookmark: { [weak self] bookmark in
            self?.bookmarkManager.remove(bookmark: bookmark, undoManager: self?.undoManager)
        }, add: { [weak self] in
            self?.showAddController()
        }, edit: { [weak self] bookmark in
            self?.showEditController(for: bookmark)
        }, moveFavorite: { [weak self] (bookmark, index) in
            self?.bookmarkManager.moveFavorites(with: [bookmark.id], toIndex: index) { _ in }
        }, onFaviconMissing: { [weak self] in
            self?.faviconsFetcherOnboarding?.presentOnboardingIfNeeded()
        })
    }

    func createAddressBarModel() -> HomePage.Models.AddressBarModel {
        HomePage.Models.AddressBarModel(
            tabCollectionViewModel: tabCollectionViewModel,
            privacyConfigurationManager: privacyConfigurationManager
        )
    }

    func refreshFavoritesModel() {
        favoritesModel.favorites = bookmarkManager.list?.favoriteBookmarks ?? []
    }

    func refreshContinueSetUpModel() {
        featuresModel.refreshFeaturesMatrix()
    }

    func refreshRecentlyVisitedModel() {
        recentlyVisitedModel.refreshWithHistory(historyCoordinating.history ?? [])
    }

    func refreshDefaultBrowserModel() {
        let prefs = DefaultBrowserPreferences.shared
        if prefs.isDefault {
            defaultBrowserDismissed = false
        }

        defaultBrowserModel.isDefault = prefs.isDefault
        defaultBrowserModel.wasClosed = defaultBrowserDismissed
    }

    func subscribeToBookmarks() {
        bookmarkManager.listPublisher.receive(on: DispatchQueue.main).sink { [weak self] _ in
            withAnimation {
                self?.refreshFavoritesModel()
            }
        }.store(in: &cancellables)
    }

    private func openUrl(_ url: URL, target: HomePage.Models.FavoritesModel.OpenTarget? = nil) {
        if target == .newWindow || NSApplication.shared.isCommandPressed && NSApplication.shared.isOptionPressed {
            WindowsManager.openNewWindow(with: url, source: .bookmark, isBurner: tabCollectionViewModel.isBurner)
            return
        }

        if target == .newTab || NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
            tabCollectionViewModel.appendNewTab(with: .contentFromURL(url, source: .bookmark), selected: true)
            return
        }

        if NSApplication.shared.isCommandPressed {
            tabCollectionViewModel.appendNewTab(with: .contentFromURL(url, source: .bookmark), selected: false)
            return
        }

        tabCollectionViewModel.selectedTabViewModel?.tab.setContent(.contentFromURL(url, source: .bookmark))
    }

    private func showAddController() {
        BookmarksDialogViewFactory.makeAddFavoriteView()
            .show(in: view.window)
    }

    private func showEditController(for bookmark: Bookmark) {
        BookmarksDialogViewFactory.makeEditBookmarkView(bookmark: bookmark)
            .show(in: view.window)
    }

    private func showSettingsOnboardingIfNeeded() {
        if addressBarModel.shouldShowAddressBar && !settingsVisibilityModel.didShowSettingsOnboarding {
            // async dispatch in order to get the final value for self.view.bounds
            DispatchQueue.main.async {
                guard let superview = self.view.superview else {
                    return
                }
                let bounds = self.view.bounds
                let settingsButtonWidth = Application.appDelegate.homePageSettingsModel.settingsButtonWidth

                let rect = NSRect(
                    x: bounds.maxX - HomePage.Views.RootView.customizeButtonPadding - settingsButtonWidth,
                    y: bounds.maxY - HomePage.Views.RootView.customizeButtonPadding - HomePage.Views.RootView.SettingsButtonView.height,
                    width: settingsButtonWidth,
                    height: HomePage.Views.RootView.SettingsButtonView.height)

                // Create a helper view as anchor for the popover and align it with the 'Customize' button.
                // This is to ensure that popover updates its position correctly as the window is resized.
                let popoverAnchorView = NSView(frame: rect)
                superview.addSubview(popoverAnchorView, positioned: .below, relativeTo: self.view)
                popoverAnchorView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    popoverAnchorView.widthAnchor.constraint(equalToConstant: settingsButtonWidth),
                    popoverAnchorView.heightAnchor.constraint(equalToConstant: HomePage.Views.RootView.SettingsButtonView.height),
                    popoverAnchorView.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: -HomePage.Views.RootView.customizeButtonPadding),
                    popoverAnchorView.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -HomePage.Views.RootView.customizeButtonPadding)
                ])

                let viewController = PopoverMessageViewController(
                    title: UserText.homePageSettingsOnboardingTitle,
                    message: UserText.homePageSettingsOnboardingMessage,
                    image: .settingsOnboardingPopover,
                    shouldShowCloseButton: true,
                    presentMultiline: true,
                    autoDismissDuration: nil,
                    onClick: { [weak self] in
                        self?.settingsVisibilityModel.isSettingsVisible = true
                    }
                )
                viewController.show(onParent: self, relativeTo: popoverAnchorView, preferredEdge: .maxY)
                self.settingsVisibilityModel.didShowSettingsOnboarding = true

                // Hide the popover as soon as settings is shown ('Customize' button is clicked).
                self.settingsVisibilityModel.$isSettingsVisible
                    .filter { $0 }
                    .prefix(1)
                    .sink { [weak viewController] _ in
                        viewController?.dismiss()
                        popoverAnchorView.removeFromSuperview()
                    }
                    .store(in: &self.cancellables)
            }
        }
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
