//
//  MainMenuTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import XCTest
import Combine
import BrowserServicesKit
@testable import DuckDuckGo_Privacy_Browser

class MainMenuTests: XCTestCase {

    typealias ReopenMenuItemKeyEquivalentManager = HistoryMenu.ReopenMenuItemKeyEquivalentManager

    @Published var isInInitialState = true

    var lastSessionMenuItem: NSMenuItem!
    var lastTabMenuItem: NSMenuItem!
    var manager: ReopenMenuItemKeyEquivalentManager!

    override func setUpWithError() throws {
        isInInitialState = true
        lastSessionMenuItem = NSMenuItem()
        lastTabMenuItem = NSMenuItem()
    }

    func testWhenIsInInitialState_AndCanRestoreState_ThenLastSessionMenuItemHasShortcut() {
        manager = .init(isInInitialStatePublisher: $isInInitialState, canRestoreLastSessionState: true)
        manager.lastSessionMenuItem = lastSessionMenuItem
        manager.reopenLastClosedMenuItem = lastTabMenuItem

        isInInitialState = true

        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalent, ReopenMenuItemKeyEquivalentManager.Const.keyEquivalent)
        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalentModifierMask, ReopenMenuItemKeyEquivalentManager.Const.modifierMask)
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalent, "")
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalentModifierMask, .command)
    }

    func testWhenIsInInitialState_AndCannotRestoreState_ThenLastTabMenuItemHasShortcut() {
        manager = .init(isInInitialStatePublisher: $isInInitialState, canRestoreLastSessionState: false)
        manager.lastSessionMenuItem = lastSessionMenuItem
        manager.reopenLastClosedMenuItem = lastTabMenuItem

        isInInitialState = true

        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalent, "")
        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalentModifierMask, .command)
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalent, ReopenMenuItemKeyEquivalentManager.Const.keyEquivalent)
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalentModifierMask, ReopenMenuItemKeyEquivalentManager.Const.modifierMask)
    }

    func testWhenIsNotInInitialState_AndCanRestoreState_ThenLastTabMenuItemHasShortcut() {
        manager = .init(isInInitialStatePublisher: $isInInitialState, canRestoreLastSessionState: true)
        manager.lastSessionMenuItem = lastSessionMenuItem
        manager.reopenLastClosedMenuItem = lastTabMenuItem

        isInInitialState = false

        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalent, "")
        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalentModifierMask, .command)
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalent, ReopenMenuItemKeyEquivalentManager.Const.keyEquivalent)
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalentModifierMask, ReopenMenuItemKeyEquivalentManager.Const.modifierMask)
    }

    func testWhenIsNotInInitialState_AndCannotRestoreState_ThenLastTabMenuItemHasShortcut() {
        manager = .init(isInInitialStatePublisher: $isInInitialState, canRestoreLastSessionState: false)
        manager.lastSessionMenuItem = lastSessionMenuItem
        manager.reopenLastClosedMenuItem = lastTabMenuItem

        isInInitialState = false

        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalent, "")
        XCTAssertEqual(manager.lastSessionMenuItem?.keyEquivalentModifierMask, .command)
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalent, ReopenMenuItemKeyEquivalentManager.Const.keyEquivalent)
        XCTAssertEqual(manager.reopenLastClosedMenuItem?.keyEquivalentModifierMask, ReopenMenuItemKeyEquivalentManager.Const.modifierMask)
    }

    // MARK: - Add To Dock Action

    @MainActor
    func testWhenBrowserIsAddedToDockThenMenuItemIsHidden() throws {
        let dockCustomizer = DockCustomizerMock()
        dockCustomizer.addToDock()

        let sut = MainMenu(
            featureFlagger: DummyFeatureFlagger(),
            bookmarkManager: MockBookmarkManager(),
            faviconManager: FaviconManagerMock(),
            dockCustomizer: dockCustomizer,
            aiChatMenuConfig: DummyAIChatConfig()
        )

        sut.update()

        let duckDuckGoMenu = try XCTUnwrap(sut.items.first?.submenu)

        XCTAssertEqual(duckDuckGoMenu.items[3].title, UserText.addDuckDuckGoToDock)
        XCTAssertTrue(duckDuckGoMenu.items[3].isHidden)
    }

#if SPARKLE
    @MainActor
    func testWhenBrowserIsNotInTheDockThenMenuItemIsVisible() throws {
        let dockCustomizer = DockCustomizerMock()

        let sut = MainMenu(
            featureFlagger: DummyFeatureFlagger(),
            bookmarkManager: MockBookmarkManager(),
            faviconManager: FaviconManagerMock(),
            dockCustomizer: dockCustomizer,
            aiChatMenuConfig: DummyAIChatConfig()
        )

        sut.update()

        let duckDuckGoMenu = try XCTUnwrap(sut.items.first?.submenu)

        XCTAssertEqual(duckDuckGoMenu.items[3].isHidden, false)
        XCTAssertEqual(duckDuckGoMenu.items[3].title, UserText.addDuckDuckGoToDock)
    }

    @MainActor
    func testWhenBrowserIsInTheDockThenMenuItemIsNotVisible() throws {
        let dockCustomizer = DockCustomizerMock()
        dockCustomizer.dockStatus = true

        let sut = MainMenu(
            featureFlagger: DummyFeatureFlagger(),
            bookmarkManager: MockBookmarkManager(),
            faviconManager: FaviconManagerMock(),
            dockCustomizer: dockCustomizer,
            aiChatMenuConfig: DummyAIChatConfig()
        )

        sut.update()

        let duckDuckGoMenu = try XCTUnwrap(sut.items.first?.submenu)

        XCTAssertEqual(duckDuckGoMenu.items[3].isHidden, true)
        XCTAssertEqual(duckDuckGoMenu.items[3].title, UserText.addDuckDuckGoToDock)
    }
#endif

    // MARK: - Default Browser Action

    @MainActor
    func testWhenBrowserIsDefaultThenSetAsDefaultBrowserMenuItemIsHidden() throws {
        let defaultBrowserProvider = DefaultBrowserProviderMock()
        defaultBrowserProvider.isDefault = true

        let sut = MainMenu(
            featureFlagger: DummyFeatureFlagger(),
            bookmarkManager: MockBookmarkManager(),
            faviconManager: FaviconManagerMock(),
            defaultBrowserPreferences: .init(defaultBrowserProvider: defaultBrowserProvider),
            aiChatMenuConfig: DummyAIChatConfig()
        )

        sut.update()

        let duckDuckGoMenu = try XCTUnwrap(sut.items.first?.submenu)

        XCTAssertEqual(duckDuckGoMenu.items[4].title, UserText.setAsDefaultBrowser + "…")
        XCTAssertTrue(duckDuckGoMenu.items[4].isHidden)
    }

    @MainActor
    func testWhenBrowserIsNotDefaultThenSetAsDefaultBrowserMenuItemIsShown() throws {
        let defaultBrowserProvider = DefaultBrowserProviderMock()
        defaultBrowserProvider.isDefault = false

        let sut = MainMenu(
            featureFlagger: DummyFeatureFlagger(),
            bookmarkManager: MockBookmarkManager(),
            faviconManager: FaviconManagerMock(),
            defaultBrowserPreferences: .init(defaultBrowserProvider: defaultBrowserProvider),
            aiChatMenuConfig: DummyAIChatConfig()
        )

        sut.update()

        let duckDuckGoMenu = try XCTUnwrap(sut.items.first?.submenu)

        XCTAssertEqual(duckDuckGoMenu.items[4].title, UserText.setAsDefaultBrowser + "…")
        XCTAssertFalse(duckDuckGoMenu.items[4].isHidden)
    }

    // MARK: - Bookmarks

    @MainActor
    func testWhenBookmarksMenuIsInitialized_ThenSecondItemIsBookmarkAllTabs() throws {
        // GIVEN
        let sut = MainMenu(featureFlagger: DummyFeatureFlagger(), bookmarkManager: MockBookmarkManager(), faviconManager: FaviconManagerMock(), aiChatMenuConfig: DummyAIChatConfig())
        let bookmarksMenu = try XCTUnwrap(sut.item(withTitle: UserText.bookmarks))

        // WHEN
        let result = try XCTUnwrap(bookmarksMenu.submenu?.item(withTitle: UserText.bookmarkAllTabs))

        // THEN
        XCTAssertEqual(result.keyEquivalent, "d")
        XCTAssertEqual(result.keyEquivalentModifierMask, [.command, .shift])
    }

    // MARK: - AI Chat

    @MainActor
    func testMainMenuInitializedWithFalseAiChatFlag_ThenAiChatIsNotVisible() throws {
        // GIVEN
        let aiChatConfig = DummyAIChatConfig()
        let sut = MainMenu(featureFlagger: DummyFeatureFlagger(),
                           bookmarkManager: MockBookmarkManager(),
                           faviconManager: FaviconManagerMock(),
                           aiChatMenuConfig: aiChatConfig)

        let fileMenu = try XCTUnwrap(sut.item(withTitle: UserText.mainMenuFile))

        // WHEN
        let aiChatMenu = fileMenu.submenu?.item(withTitle: UserText.newAIChatMenuItem)

        // THEN
        XCTAssertNotNil(aiChatMenu, "AI Chat menu item should exist in the file menu.")
        XCTAssertTrue(aiChatMenu?.isHidden == true, "AI Chat menu item should be hidden when the AI chat flag is false.")
    }

    @MainActor
    func testMainMenuInitializedWithTrueAiChatFlag_ThenAiChatIsVisible() throws {
        // GIVEN
        let aiChatConfig = DummyAIChatConfig()
        aiChatConfig.shouldDisplayApplicationMenuShortcut = true
        aiChatConfig.isFeatureEnabledForApplicationMenuShortcut = true

        let sut = MainMenu(featureFlagger: DummyFeatureFlagger(),
                           bookmarkManager: MockBookmarkManager(),
                           faviconManager: FaviconManagerMock(),
                           aiChatMenuConfig: aiChatConfig)

        let fileMenu = try XCTUnwrap(sut.item(withTitle: UserText.mainMenuFile))

        // WHEN
        let aiChatMenu = fileMenu.submenu?.item(withTitle: UserText.newAIChatMenuItem)

        // THEN
        XCTAssertNotNil(aiChatMenu, "AI Chat menu item should exist in the file menu.")
        XCTAssertFalse(aiChatMenu?.isHidden ?? true, "AI Chat menu item should be visible when the AI chat flag is true.")
    }
}

private class DummyFeatureFlagger: FeatureFlagger {
    var internalUserDecider: InternalUserDecider = DefaultInternalUserDecider(store: MockInternalUserStoring())
    var localOverrides: FeatureFlagLocalOverriding?

    func isFeatureOn<Flag: FeatureFlagDescribing>(for: Flag, allowOverride: Bool) -> Bool {
        false
    }

    func getCohortIfEnabled(_ subfeature: any PrivacySubfeature) -> CohortID? {
        return nil
    }

    func resolveCohort<Flag>(for featureFlag: Flag, allowOverride: Bool) -> (any FeatureFlagCohortDescribing)? where Flag: FeatureFlagDescribing {
        return nil
    }

    var allActiveExperiments: Experiments = [:]
}

private class DummyAIChatConfig: AIChatMenuVisibilityConfigurable {
    var shouldDisplayApplicationMenuShortcut = false
    var shouldDisplayToolbarShortcut = false
    var isFeatureEnabledForApplicationMenuShortcut = false
    var isFeatureEnabledForToolbarShortcut = false

    var valuesChangedPublisher: PassthroughSubject<Void, Never> {
        return PassthroughSubject<Void, Never>()
    }

    var shouldDisplayToolbarOnboardingPopover: PassthroughSubject<Void, Never> {
        return PassthroughSubject<Void, Never>()
    }

    func markToolbarOnboardingPopoverAsShown() { }
}
