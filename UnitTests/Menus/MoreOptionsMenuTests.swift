//
//  MoreOptionsMenuTests.swift
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

import Combine
import NetworkProtection
import NetworkProtectionUI
import XCTest
import Subscription
import SubscriptionTestingUtilities
import BrowserServicesKit
import DataBrokerProtection

@testable import DuckDuckGo_Privacy_Browser

final class MoreOptionsMenuTests: XCTestCase {

    var tabCollectionViewModel: TabCollectionViewModel!
    var passwordManagerCoordinator: PasswordManagerCoordinator!
    var networkProtectionVisibilityMock: NetworkProtectionVisibilityMock!
    var capturingActionDelegate: CapturingOptionsButtonMenuDelegate!
    var internalUserDecider: InternalUserDeciderMock!
    var defaultBrowserProvider: DefaultBrowserProviderMock!
    var dockCustomizer: DockCustomizerMock!

    var storePurchaseManager: StorePurchaseManager!

    var subscriptionManager: SubscriptionManagerMock!

    private var mockFreemiumDBPPresenter = MockFreemiumDBPPresenter()
    private var mockFreemiumDBPFeature: MockFreemiumDBPFeature!
    private var mockNotificationCenter: MockNotificationCenter!
    private var mockPixelHandler: MockFreemiumDBPExperimentPixelHandler!
    private var mockFreemiumDBPUserStateManager: MockFreemiumDBPUserStateManager!

    var moreOptionsMenu: MoreOptionsMenu!

    @MainActor
    override func setUp() {
        super.setUp()
        tabCollectionViewModel = TabCollectionViewModel()
        passwordManagerCoordinator = PasswordManagerCoordinator()
        networkProtectionVisibilityMock = NetworkProtectionVisibilityMock(isInstalled: false, visible: false)
        capturingActionDelegate = CapturingOptionsButtonMenuDelegate()
        internalUserDecider = InternalUserDeciderMock()
        defaultBrowserProvider = DefaultBrowserProviderMock()
        dockCustomizer = DockCustomizerMock()
        dockCustomizer.addToDock()
        defaultBrowserProvider.isDefault = true

        storePurchaseManager = StorePurchaseManagerMock()

        subscriptionManager = SubscriptionManagerMock(accountManager: AccountManagerMock(),
                                                      subscriptionEndpointService: SubscriptionEndpointServiceMock(),
                                                      authEndpointService: AuthEndpointServiceMock(),
                                                      storePurchaseManager: storePurchaseManager,
                                                      currentEnvironment: SubscriptionEnvironment(serviceEnvironment: .production,
                                                                                                  purchasePlatform: .appStore),
                                                      canPurchase: false,
                                                      subscriptionFeatureMappingCache: SubscriptionFeatureMappingCacheMock())

        mockFreemiumDBPFeature = MockFreemiumDBPFeature()

        mockNotificationCenter = MockNotificationCenter()
        mockPixelHandler = MockFreemiumDBPExperimentPixelHandler()
        mockFreemiumDBPUserStateManager = MockFreemiumDBPUserStateManager()
    }

    @MainActor
    override func tearDown() {
        tabCollectionViewModel = nil
        passwordManagerCoordinator = nil
        capturingActionDelegate = nil
        subscriptionManager = nil
        moreOptionsMenu = nil
        super.tearDown()
    }

    @MainActor
    private func setupMoreOptionsMenu() {
        moreOptionsMenu = MoreOptionsMenu(tabCollectionViewModel: tabCollectionViewModel,
                                          passwordManagerCoordinator: passwordManagerCoordinator,
                                          vpnFeatureGatekeeper: networkProtectionVisibilityMock,
                                          subscriptionFeatureAvailability: SubscriptionFeatureAvailabilityMock(isSubscriptionPurchaseAllowed: true,
                                                                                                               usesUnifiedFeedbackForm: false),
                                          sharingMenu: NSMenu(),
                                          internalUserDecider: internalUserDecider,
                                          subscriptionManager: subscriptionManager,
                                          freemiumDBPUserStateManager: mockFreemiumDBPUserStateManager,
                                          freemiumDBPFeature: mockFreemiumDBPFeature,
                                          freemiumDBPPresenter: mockFreemiumDBPPresenter,
                                          dockCustomizer: dockCustomizer,
                                          defaultBrowserPreferences: .init(defaultBrowserProvider: defaultBrowserProvider),
                                          notificationCenter: mockNotificationCenter,
                                          freemiumDBPExperimentPixelHandler: mockPixelHandler)

        moreOptionsMenu.actionDelegate = capturingActionDelegate
    }

    // MARK: - Subscription & Freemium

    private func mockAuthentication() {
        subscriptionManager.accountManager.storeAuthToken(token: "")
        subscriptionManager.accountManager.storeAccount(token: "", email: "", externalID: "")
    }

    @MainActor
    func testThatPrivacyProIsNotPresentWhenUnauthenticatedAndPurchaseNotAllowedOnAppStore () {
        subscriptionManager.canPurchase = false
        subscriptionManager.currentEnvironment = SubscriptionEnvironment(serviceEnvironment: .production, purchasePlatform: .appStore)

        setupMoreOptionsMenu()

        XCTAssertFalse(subscriptionManager.accountManager.isUserAuthenticated)
        XCTAssertFalse(moreOptionsMenu.items.map { $0.title }.contains(UserText.subscriptionOptionsMenuItem))
    }

    @MainActor
    func testThatPrivacyProIsPresentWhenUnauthenticatedAndPurchaseAllowedOnAppStore () {
        subscriptionManager.canPurchase = true
        subscriptionManager.currentEnvironment = SubscriptionEnvironment(serviceEnvironment: .production, purchasePlatform: .appStore)

        setupMoreOptionsMenu()

        XCTAssertFalse(subscriptionManager.accountManager.isUserAuthenticated)
        XCTAssertTrue(moreOptionsMenu.items.map { $0.title }.contains(UserText.subscriptionOptionsMenuItem))
    }

    @MainActor
    func testThatPrivacyProIsPresentDespiteCanPurchaseFlagOnStripe () {
        subscriptionManager.canPurchase = false
        subscriptionManager.currentEnvironment = SubscriptionEnvironment(serviceEnvironment: .production, purchasePlatform: .stripe)

        setupMoreOptionsMenu()

        XCTAssertFalse(subscriptionManager.accountManager.isUserAuthenticated)
        XCTAssertTrue(moreOptionsMenu.items.map { $0.title }.contains(UserText.subscriptionOptionsMenuItem))
    }

    @MainActor
    func testThatMoreOptionMenuHasTheExpectedItemsWhenFreemiumFeatureUnavailable() {
        subscriptionManager.canPurchase = true
        subscriptionManager.currentEnvironment = SubscriptionEnvironment(serviceEnvironment: .production, purchasePlatform: .stripe)
        mockFreemiumDBPFeature.featureAvailable = false

        setupMoreOptionsMenu()

        XCTAssertFalse(subscriptionManager.accountManager.isUserAuthenticated)
        XCTAssertTrue(subscriptionManager.canPurchase)

        XCTAssertEqual(moreOptionsMenu.items[0].title, UserText.sendFeedback)
        XCTAssertTrue(moreOptionsMenu.items[1].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[2].title, UserText.plusButtonNewTabMenuItem)
        XCTAssertEqual(moreOptionsMenu.items[3].title, UserText.newWindowMenuItem)
        XCTAssertEqual(moreOptionsMenu.items[4].title, UserText.newBurnerWindowMenuItem)
        XCTAssertTrue(moreOptionsMenu.items[5].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[6].title, UserText.zoom)
        XCTAssertTrue(moreOptionsMenu.items[7].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[8].title, UserText.bookmarks)
        XCTAssertEqual(moreOptionsMenu.items[9].title, UserText.downloads)
        XCTAssertEqual(moreOptionsMenu.items[10].title, UserText.passwordManagementTitle)
        XCTAssertTrue(moreOptionsMenu.items[11].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[12].title, UserText.emailOptionsMenuItem)
        XCTAssertTrue(moreOptionsMenu.items[13].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[14].title, UserText.subscriptionOptionsMenuItem)
        XCTAssertFalse(moreOptionsMenu.items[14].hasSubmenu)
        XCTAssertTrue(moreOptionsMenu.items[15].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[16].title, UserText.mainMenuHelp)
        XCTAssertEqual(moreOptionsMenu.items[17].title, UserText.settings)
    }

    @MainActor
    func testThatMoreOptionMenuHasTheExpectedItemsWhenFreemiumFeatureAvailable() {
        subscriptionManager.canPurchase = true
        subscriptionManager.currentEnvironment = SubscriptionEnvironment(serviceEnvironment: .production, purchasePlatform: .stripe)
        mockFreemiumDBPFeature.featureAvailable = true

        setupMoreOptionsMenu()

        XCTAssertFalse(subscriptionManager.accountManager.isUserAuthenticated)
        XCTAssertTrue(subscriptionManager.canPurchase)

        XCTAssertEqual(moreOptionsMenu.items[0].title, UserText.sendFeedback)
        XCTAssertTrue(moreOptionsMenu.items[1].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[2].title, UserText.plusButtonNewTabMenuItem)
        XCTAssertEqual(moreOptionsMenu.items[3].title, UserText.newWindowMenuItem)
        XCTAssertEqual(moreOptionsMenu.items[4].title, UserText.newBurnerWindowMenuItem)
        XCTAssertTrue(moreOptionsMenu.items[5].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[6].title, UserText.zoom)
        XCTAssertTrue(moreOptionsMenu.items[7].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[8].title, UserText.bookmarks)
        XCTAssertEqual(moreOptionsMenu.items[9].title, UserText.downloads)
        XCTAssertEqual(moreOptionsMenu.items[10].title, UserText.passwordManagementTitle)
        XCTAssertTrue(moreOptionsMenu.items[11].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[12].title, UserText.emailOptionsMenuItem)
        XCTAssertTrue(moreOptionsMenu.items[13].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[14].title, UserText.subscriptionOptionsMenuItem)
        XCTAssertFalse(moreOptionsMenu.items[14].hasSubmenu)
        XCTAssertEqual(moreOptionsMenu.items[15].title, UserText.freemiumDBPOptionsMenuItem)
        XCTAssertTrue(moreOptionsMenu.items[16].isSeparatorItem)
        XCTAssertEqual(moreOptionsMenu.items[17].title, UserText.mainMenuHelp)
        XCTAssertEqual(moreOptionsMenu.items[18].title, UserText.settings)
    }

    @MainActor
    func testWhenClickingFreemiumDBPOptionThenFreemiumPresenterIsCalledAndNotificationIsPostedAndPixelFired() throws {
        // Given
        subscriptionManager.canPurchase = true
        subscriptionManager.currentEnvironment = SubscriptionEnvironment(serviceEnvironment: .production, purchasePlatform: .stripe)
        mockFreemiumDBPFeature.featureAvailable = true
        setupMoreOptionsMenu()

        let freemiumItemIndex = try XCTUnwrap(moreOptionsMenu.indexOfItem(withTitle: UserText.freemiumDBPOptionsMenuItem))

        // When
        moreOptionsMenu.performActionForItem(at: freemiumItemIndex)

        // Then
        XCTAssertTrue(mockFreemiumDBPPresenter.didCallShowFreemium)
        XCTAssertTrue(mockNotificationCenter.didCallPostNotification)
        XCTAssertEqual(mockNotificationCenter.lastPostedNotification, .freemiumDBPEntryPointActivated)
        XCTAssertEqual(mockPixelHandler.lastFiredEvent, FreemiumDBPExperimentPixel.overFlowScan)
    }

    @MainActor
    func testWhenClickingFreemiumDBPOptionAndFreemiumActivatedThenFreemiumPresenterIsCalledAndNotificationIsPostedAndPixelFired() throws {
        // Given
        mockFreemiumDBPUserStateManager.didPostFirstProfileSavedNotification = true
        subscriptionManager.canPurchase = true
        subscriptionManager.currentEnvironment = SubscriptionEnvironment(serviceEnvironment: .production, purchasePlatform: .stripe)
        mockFreemiumDBPFeature.featureAvailable = true
        setupMoreOptionsMenu()

        let freemiumItemIndex = try XCTUnwrap(moreOptionsMenu.indexOfItem(withTitle: UserText.freemiumDBPOptionsMenuItem))

        // When
        moreOptionsMenu.performActionForItem(at: freemiumItemIndex)

        // Then
        XCTAssertTrue(mockFreemiumDBPPresenter.didCallShowFreemium)
        XCTAssertTrue(mockNotificationCenter.didCallPostNotification)
        XCTAssertEqual(mockNotificationCenter.lastPostedNotification, .freemiumDBPEntryPointActivated)
        XCTAssertEqual(mockPixelHandler.lastFiredEvent, FreemiumDBPExperimentPixel.overFlowResults)
    }

    // MARK: Zoom

    @MainActor
    func testWhenClickingDefaultZoomInZoomSubmenuThenTheActionDelegateIsAlerted() {
        setupMoreOptionsMenu()

        guard let zoomSubmenu = moreOptionsMenu.zoomMenuItem.submenu else {
            XCTFail("No zoom submenu available")
            return
        }
        let defaultZoomItemIndex = zoomSubmenu.indexOfItem(withTitle: UserText.defaultZoomPageMoreOptionsItem)

        zoomSubmenu.performActionForItem(at: defaultZoomItemIndex)

        XCTAssertTrue(capturingActionDelegate.optionsButtonMenuRequestedAccessibilityPreferencesCalled)
    }

    // MARK: Preferences
    @MainActor
    func testWhenClickingOnPreferenceMenuItemThenTheActionDelegateIsAlerted() {
        setupMoreOptionsMenu()

        moreOptionsMenu.performActionForItem(at: moreOptionsMenu.items.count - 1)
        XCTAssertTrue(capturingActionDelegate.optionsButtonMenuRequestedPreferencesCalled)
    }

    // MARK: - Bookmarks

    @MainActor
    func testWhenClickingOnBookmarkAllTabsMenuItemThenTheActionDelegateIsAlerted() throws {
        setupMoreOptionsMenu()

        // GIVEN
        let bookmarksMenu = try XCTUnwrap(moreOptionsMenu.item(at: 8)?.submenu)
        let bookmarkAllTabsIndex = try XCTUnwrap(bookmarksMenu.indexOfItem(withTitle: UserText.bookmarkAllTabs))
        let bookmarkAllTabsMenuItem = try XCTUnwrap(bookmarksMenu.items[bookmarkAllTabsIndex])
        bookmarkAllTabsMenuItem.isEnabled = true

        // WHEN
        bookmarksMenu.performActionForItem(at: bookmarkAllTabsIndex)

        // THEN
        XCTAssertTrue(capturingActionDelegate.optionsButtonMenuRequestedBookmarkAllOpenTabsCalled)
    }

    // MARK: - Default Browser Action and Add To Dock

#if SPARKLE
    @MainActor
    func testWhenBrowserIsNotAddedToDockThenMenuItemIsVisible() {
        dockCustomizer.didShowFeatureFromMoreOptionsMenu = true
        dockCustomizer.dockStatus = false

        setupMoreOptionsMenu()
        moreOptionsMenu.update()

        XCTAssertEqual(moreOptionsMenu.items[1].title, UserText.addDuckDuckGoToDock)
    }

    @MainActor
    func testWhenBrowserIsNotInTheDockAndIsNotSetAsDefaultThenTheOrderIsCorrect() {
        dockCustomizer.didShowFeatureFromMoreOptionsMenu = true
        dockCustomizer.dockStatus = false
        defaultBrowserProvider.isDefault = false

        setupMoreOptionsMenu()
        moreOptionsMenu.update()

        XCTAssertEqual(moreOptionsMenu.items[1].title, UserText.addDuckDuckGoToDock)
        XCTAssertEqual(moreOptionsMenu.items[2].title, UserText.setAsDefaultBrowser)
    }
#endif

    @MainActor
    func testWhenBrowserIsAddedToDockThenMenuItemIsNotVisible() {
        dockCustomizer.dockStatus = true

        setupMoreOptionsMenu()
        moreOptionsMenu.update()

        XCTAssertNotEqual(moreOptionsMenu.items[1].title, UserText.addDuckDuckGoToDock)
    }

    @MainActor
    func testWhenBrowserIsDefaultThenSetAsDefaultBrowserMenuItemIsHidden() {
        defaultBrowserProvider.isDefault = true

        setupMoreOptionsMenu()
        moreOptionsMenu.update()

        XCTAssertNotEqual(moreOptionsMenu.items[1].title, UserText.setAsDefaultBrowser)
    }

    @MainActor
    func testWhenBrowserIsNotDefaultThenSetAsDefaultBrowserMenuItemIsShown() {
        defaultBrowserProvider.isDefault = false

        setupMoreOptionsMenu()
        moreOptionsMenu.update()

        XCTAssertEqual(moreOptionsMenu.items[1].title, UserText.setAsDefaultBrowser)
    }
}

final class NetworkProtectionVisibilityMock: VPNFeatureGatekeeper {

    var onboardStatusPublisher: AnyPublisher<NetworkProtectionUI.OnboardingStatus, Never> {
        Just(.default).eraseToAnyPublisher()
    }

    var isInstalled: Bool
    var visible: Bool

    init(isInstalled: Bool, visible: Bool) {
        self.isInstalled = isInstalled
        self.visible = visible
    }

    func isVPNVisible() -> Bool {
        return visible
    }

    func shouldUninstallAutomatically() -> Bool {
        return !visible
    }

    func canStartVPN() async throws -> Bool {
        return false
    }

    func disableForAllUsers() async {
        // intentional no-op
    }

    func disableIfUserHasNoAccess() async {
        // Intentional no-op
    }
}

final class MockFreemiumDBPFeature: FreemiumDBPFeature {
    var featureAvailable = false {
        didSet {
            isAvailableSubject.send(featureAvailable)
        }
    }
    var isAvailableSubject = PassthroughSubject<Bool, Never>()

    var isAvailable: Bool {
        featureAvailable
    }

    var isAvailablePublisher: AnyPublisher<Bool, Never> {
        return isAvailableSubject.eraseToAnyPublisher()
    }

    func subscribeToDependencyUpdates() {}
}

final class MockFreemiumDBPPresenter: FreemiumDBPPresenter {
    var didCallShowFreemium = false

    func showFreemiumDBPAndSetActivated(windowControllerManager: WindowControllersManagerProtocol? = nil) {
        didCallShowFreemium = true
    }
}
