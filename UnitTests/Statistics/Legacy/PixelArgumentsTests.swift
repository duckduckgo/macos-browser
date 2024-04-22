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

@MainActor
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
        let ap = GeneralPixel.AccessPoint(sender: NSButton(), default: .tabMenu)
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
        let ap = GeneralPixel.AccessPoint(sender: mainMenu.item, default: .tabMenu) { $0 === mainMenu.menu }
        XCTAssertEqual(ap, .mainMenu)
    }

    func testWhenInitWithHotKeyThenAccessPointIsHotKey() {
        let mainMenu = makeMenu()
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                     timestamp: Date().timeIntervalSinceReferenceDate, windowNumber: 0,
                                     context: nil, characters: "x", charactersIgnoringModifiers: "",
                                     isARepeat: false, keyCode: UInt16(kVK_ANSI_X))!
        NSApp.setValue(event, forKey: "currentEvent")
        let ap = GeneralPixel.AccessPoint(sender: mainMenu.item, default: .tabMenu) { $0 === mainMenu.menu }
        XCTAssertEqual(ap, .hotKey)
    }

    func testWhenInitWithMenuChosenByCmdEnterThenAccessPointIsMainMenu() {
        let mainMenu = makeMenu()
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                     timestamp: Date().timeIntervalSinceReferenceDate, windowNumber: 0,
                                     context: nil, characters: "\n", charactersIgnoringModifiers: "",
                                     isARepeat: false, keyCode: UInt16(kVK_Return))!
        NSApp.setValue(event, forKey: "currentEvent")
        let ap = GeneralPixel.AccessPoint(sender: mainMenu.item, default: .tabMenu) { $0 === mainMenu.menu }
        XCTAssertEqual(ap, .mainMenu)
    }

    func testWhenInitWithMenuChosenByCmdSpaceThenAccessPointIsMainMenu() {
        let mainMenu = makeMenu()
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                     timestamp: Date().timeIntervalSinceReferenceDate, windowNumber: 0,
                                     context: nil, characters: " ", charactersIgnoringModifiers: "",
                                     isARepeat: false, keyCode: UInt16(kVK_Space))!
        NSApp.setValue(event, forKey: "currentEvent")
        let ap = GeneralPixel.AccessPoint(sender: mainMenu.item, default: .tabMenu) { $0 === mainMenu.menu }
        XCTAssertEqual(ap, .mainMenu)
    }

    func testWhenInitWithTabMenuItemThenAccessPointIsMenu() {
        let mainMenu = makeMenu()
        let tabMenu = makeMenu()
        let ap = GeneralPixel.AccessPoint(sender: tabMenu.item, default: .tabMenu) { $0 === mainMenu.menu }
        XCTAssertEqual(ap, .tabMenu)
    }

    // MARK: Repetition

    func testWhenInitFirstTimeThenRepetitionIsInitial() {
        let rep1 = GeneralPixel.Repetition(key: "test", store: pixelDataStore)
        let rep2 = GeneralPixel.Repetition(key: "test2", store: pixelDataStore)
        XCTAssertEqual(rep1, .initial)
        XCTAssertEqual(rep2, .initial)
    }

    func testWhenInitSecondTimeThenRepetitionIsRepetitive() {
        _=GeneralPixel.Repetition(key: "test", store: pixelDataStore)
        let rep1 = GeneralPixel.Repetition(key: "test", store: pixelDataStore)
        let rep2 = GeneralPixel.Repetition(key: "test2", store: pixelDataStore)
        XCTAssertEqual(rep1, .repetitive)
        XCTAssertEqual(rep2, .initial)
    }

    func testWhenInitNextDayThenRepetitionIsDailyFirst() {
        let now = Date()
        let tomorrow = now.addingTimeInterval(3600 * 24)
        let tomorrow2 = now.addingTimeInterval(3600 * 24 + 1)
        let afterTomorrow = tomorrow.addingTimeInterval(3600 * 24)

        _=GeneralPixel.Repetition(key: "test", store: pixelDataStore, now: now)
        let rep1 = GeneralPixel.Repetition(key: "test", store: pixelDataStore, now: tomorrow)
        let rep2 = GeneralPixel.Repetition(key: "test", store: pixelDataStore, now: tomorrow2)
        let rep3 = GeneralPixel.Repetition(key: "test", store: pixelDataStore, now: afterTomorrow)

        XCTAssertEqual(rep1, .dailyFirst)
        XCTAssertEqual(rep2, .repetitive)
        XCTAssertEqual(rep3, .dailyFirst)
    }

}
