//
//  PixelArgumentsTests.swift
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

import XCTest
import Carbon
@testable import DuckDuckGo_Privacy_Browser

class PixelArgumentsTests: XCTestCase {

    var bookmarkStore: BookmarkStoreMock!
    var bookmarkManager: LocalBookmarkManager!
    var fireproofDomains: FireproofDomains!
    var pixelDataStore: PixelDataStore!

    override func setUp() {
        bookmarkStore = BookmarkStoreMock()
        bookmarkStore.bookmarks = []
        bookmarkManager = LocalBookmarkManager(bookmarkStore: bookmarkStore, faviconManagement: FaviconManagerMock())
        bookmarkManager.loadBookmarks()
        UserDefaultsWrapper<Any>.clearAll()
        fireproofDomains = FireproofDomains(store: FireproofDomainsStoreMock())
        pixelDataStore = PixelStoreMock()
    }

    override func tearDown() {
        bookmarkManager = nil
        bookmarkStore = nil
        fireproofDomains.clearAll()
        fireproofDomains = nil
        pixelDataStore = nil
        NSApp.setValue(nil, forKey: "currentEvent")
    }

    // MARK: AccessPoint

    func testWhenInitWithButtonThenAccessPointIsButton() {
        let ap = Pixel.Event.AccessPoint(sender: NSButton(), default: .tabMenu)
        XCTAssertEqual(ap, .button)
    }

    private func makeMenu() -> (menu: NSMenu, item: NSMenuItem) {
        let mainMenu = NSMenu()
        let itemA = NSMenuItem(title: "a", action: nil, keyEquivalent: "")
        mainMenu.addItem(itemA)
        let subMenu = NSMenu()
        itemA.submenu = subMenu
        let itemB = NSMenuItem(title: "b", action: nil, keyEquivalent: "x")
        subMenu.addItem(itemB)

        return (mainMenu, itemB)
    }

    func testWhenInitWithMainMenuItemThenAccessPointIsMenu() {
        let mainMenu = makeMenu()
        let ap = Pixel.Event.AccessPoint(sender: mainMenu.item, default: .tabMenu) { $0 === mainMenu.menu }
        XCTAssertEqual(ap, .mainMenu)
    }

    func testWhenInitWithHotKeyThenAccessPointIsHotKey() {
        let mainMenu = makeMenu()
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                     timestamp: Date().timeIntervalSinceReferenceDate, windowNumber: 0,
                                     context: nil, characters: "x", charactersIgnoringModifiers: "",
                                     isARepeat: false, keyCode: UInt16(kVK_ANSI_X))!
        NSApp.setValue(event, forKey: "currentEvent")
        let ap = Pixel.Event.AccessPoint(sender: mainMenu.item, default: .tabMenu) { $0 === mainMenu.menu }
        XCTAssertEqual(ap, .hotKey)
    }

    func testWhenInitWithMenuChosenByCmdEnterThenAccessPointIsMainMenu() {
        let mainMenu = makeMenu()
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                     timestamp: Date().timeIntervalSinceReferenceDate, windowNumber: 0,
                                     context: nil, characters: "\n", charactersIgnoringModifiers: "",
                                     isARepeat: false, keyCode: UInt16(kVK_Return))!
        NSApp.setValue(event, forKey: "currentEvent")
        let ap = Pixel.Event.AccessPoint(sender: mainMenu.item, default: .tabMenu) { $0 === mainMenu.menu }
        XCTAssertEqual(ap, .mainMenu)
    }

    func testWhenInitWithMenuChosenByCmdSpaceThenAccessPointIsMainMenu() {
        let mainMenu = makeMenu()
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                     timestamp: Date().timeIntervalSinceReferenceDate, windowNumber: 0,
                                     context: nil, characters: " ", charactersIgnoringModifiers: "",
                                     isARepeat: false, keyCode: UInt16(kVK_Space))!
        NSApp.setValue(event, forKey: "currentEvent")
        let ap = Pixel.Event.AccessPoint(sender: mainMenu.item, default: .tabMenu) { $0 === mainMenu.menu }
        XCTAssertEqual(ap, .mainMenu)
    }

    func testWhenInitWithTabMenuItemThenAccessPointIsMenu() {
        let mainMenu = makeMenu()
        let tabMenu = makeMenu()
        let ap = Pixel.Event.AccessPoint(sender: tabMenu.item, default: .tabMenu) { $0 === mainMenu.menu }
        XCTAssertEqual(ap, .tabMenu)
    }

    // MARK: IsBookmarkFireproofed

    func testWhenInitWithFireproofDomainThenIsBookmarkFireproofedIsFireproofed() {
        fireproofDomains.add(domain: "duckduckgo.com")
        let url = URL(string: "https://duckduckgo.com/?q=search")!
        let fp = Pixel.Event.IsBookmarkFireproofed(url: url, fireproofDomains: fireproofDomains)
        XCTAssertEqual(fp, .fireproofed)
    }

    func testWhenInitWithNonFireproofDomainThenIsBookmarkFireproofedIsNotFireproofed() {
        let url = URL(string: "https://duckduckgo.com/?q=search")!
        let fp = Pixel.Event.IsBookmarkFireproofed(url: url, fireproofDomains: fireproofDomains)
        XCTAssertEqual(fp, .nonFireproofed)
    }

    // MARK: FireproofKind

    func testWhenInitWithURLThenFireproofKindIsURL() {
        let url = URL(string: "https://duckduckgo.com")!

        let kind = Pixel.Event.FireproofKind(url: url, bookmarkManager: bookmarkManager)
        XCTAssertEqual(kind, .website)
    }

    func testWhenInitWithBookmarkedURLThenFireproofKindIsBookmark() {
        let url = URL(string: "https://duckduckgo.com")!

        bookmarkManager.makeBookmark(for: url, title: "DDG", isFavorite: false)

        let kind = Pixel.Event.FireproofKind(url: url, bookmarkManager: bookmarkManager)
        XCTAssertEqual(kind, .bookmarked)
    }

    func testWhenInitWithFavoriteURLThenFireproofKindIsBookmark() {
        let url = URL(string: "https://duckduckgo.com")!

        bookmarkManager.makeBookmark(for: url, title: "DDG", isFavorite: true)

        let kind = Pixel.Event.FireproofKind(url: url, bookmarkManager: bookmarkManager)
        XCTAssertEqual(kind, .favorite)
    }

    // MARK: Repetition

    func testWhenInitFirstTimeThenRepetitionIsInitial() {
        let rep1 = Pixel.Event.Repetition(key: "test", store: pixelDataStore)
        let rep2 = Pixel.Event.Repetition(key: "test2", store: pixelDataStore)
        XCTAssertEqual(rep1, .initial)
        XCTAssertEqual(rep2, .initial)
    }

    func testWhenInitSecondTimeThenRepetitionIsRepetitive() {
        _=Pixel.Event.Repetition(key: "test", store: pixelDataStore)
        let rep1 = Pixel.Event.Repetition(key: "test", store: pixelDataStore)
        let rep2 = Pixel.Event.Repetition(key: "test2", store: pixelDataStore)
        XCTAssertEqual(rep1, .repetitive)
        XCTAssertEqual(rep2, .initial)
    }

    func testWhenInitNextDayThenRepetitionIsDailyFirst() {
        let now = Date()
        let tomorrow = now.addingTimeInterval(3600 * 24)
        let tomorrow2 = now.addingTimeInterval(3600 * 24 + 1)
        let afterTomorrow = tomorrow.addingTimeInterval(3600 * 24)

        _=Pixel.Event.Repetition(key: "test", store: pixelDataStore, now: now)
        let rep1 = Pixel.Event.Repetition(key: "test", store: pixelDataStore, now: tomorrow)
        let rep2 = Pixel.Event.Repetition(key: "test", store: pixelDataStore, now: tomorrow2)
        let rep3 = Pixel.Event.Repetition(key: "test", store: pixelDataStore, now: afterTomorrow)

        XCTAssertEqual(rep1, .dailyFirst)
        XCTAssertEqual(rep2, .repetitive)
        XCTAssertEqual(rep3, .dailyFirst)
    }

    // MARK: AppLaunch

    func testWhenInitFirstTimeThenAppLaunchIsInitial() {
        let launch = Pixel.Event.AppLaunch.autoInitialOrRegular(store: pixelDataStore)
        XCTAssertEqual(launch, .initial)
    }

    func testWhenInitNextDayThenAppLaunchIsRegular() {
        let now = Date()
        let tomorrow = now.addingTimeInterval(3600 * 24)
        let tomorrow2 = now.addingTimeInterval(3600 * 24 + 1)
        let afterTomorrow = tomorrow.addingTimeInterval(3600 * 24)

        _=Pixel.Event.AppLaunch.autoInitialOrRegular(store: pixelDataStore, now: now)
        Pixel.Event.AppLaunch.repetition(store: pixelDataStore, now: now).update()
        let rep1 = Pixel.Event.AppLaunch.autoInitialOrRegular(store: pixelDataStore, now: tomorrow)
        Pixel.Event.AppLaunch.repetition(store: pixelDataStore, now: tomorrow).update()
        let rep2 = Pixel.Event.AppLaunch.autoInitialOrRegular(store: pixelDataStore, now: tomorrow2)
        Pixel.Event.AppLaunch.repetition(store: pixelDataStore, now: tomorrow2).update()
        let rep3 = Pixel.Event.AppLaunch.autoInitialOrRegular(store: pixelDataStore, now: afterTomorrow)

        XCTAssertEqual(rep1, .dailyFirst)
        XCTAssertEqual(rep2, .regular)
        XCTAssertEqual(rep3, .dailyFirst)
    }

    // MARK: Others

    func testIsDefaultBrowser() {
        XCTAssertEqual(Pixel.Event.IsDefaultBrowser(isDefault: true), .default)
        XCTAssertEqual(Pixel.Event.IsDefaultBrowser(isDefault: false), .nonDefault)
    }

    func testAverageTabsCount() {
        XCTAssertEqual(Pixel.Event.AverageTabsCount(avgTabs: -1), .lessThan6)
        XCTAssertEqual(Pixel.Event.AverageTabsCount(avgTabs: 0), .lessThan6)
        XCTAssertEqual(Pixel.Event.AverageTabsCount(avgTabs: 2), .lessThan6)
        XCTAssertEqual(Pixel.Event.AverageTabsCount(avgTabs: 5), .lessThan6)
        XCTAssertEqual(Pixel.Event.AverageTabsCount(avgTabs: 6.1), .moreThan6)
        XCTAssertEqual(Pixel.Event.AverageTabsCount(avgTabs: 20), .moreThan6)
    }

    func testBurnedTabs() {
        XCTAssertEqual(Pixel.Event.BurnedTabs(-1), .lessThan6)
        XCTAssertEqual(Pixel.Event.BurnedTabs(0), .lessThan6)
        XCTAssertEqual(Pixel.Event.BurnedTabs(2), .lessThan6)
        XCTAssertEqual(Pixel.Event.BurnedTabs(5), .lessThan6)
        XCTAssertEqual(Pixel.Event.BurnedTabs(6), .moreThan6)
        XCTAssertEqual(Pixel.Event.BurnedTabs(20), .moreThan6)
    }

    func testBurnedWindows() {
        XCTAssertEqual(Pixel.Event.BurnedWindows(-1), .one)
        XCTAssertEqual(Pixel.Event.BurnedWindows(0), .one)
        XCTAssertEqual(Pixel.Event.BurnedWindows(1), .one)
        XCTAssertEqual(Pixel.Event.BurnedWindows(2), .moreThan1)
        XCTAssertEqual(Pixel.Event.BurnedWindows(5), .moreThan1)
        XCTAssertEqual(Pixel.Event.BurnedWindows(6), .moreThan1)
        XCTAssertEqual(Pixel.Event.BurnedWindows(20), .moreThan1)
    }

}
