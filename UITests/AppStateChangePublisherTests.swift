//
//  AppStateChangePublisherTests.swift
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

import Combine
import XCTest

@testable import DuckDuckGo_Privacy_Browser

final class AppStateChangePublisherTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    @MainActor
    override func setUp() {
        assert(WindowControllersManager.shared.mainWindowControllers.isEmpty)
    }

    @MainActor
    override func tearDown() {
        cancellables.removeAll()
        WindowsManager.closeWindows()
        for controller in WindowControllersManager.shared.mainWindowControllers {
            WindowControllersManager.shared.unregister(controller)
        }
    }

    func expect(description expectationDescription: String, events: Int) -> XCTestExpectation {
        let e = expectation(description: description)
        e.expectedFulfillmentCount = events
        return e
    }

    // MARK: -

    @MainActor
    func testWhenWindowIsOpenedThenStateChangePublished() {
        let e = expectation(description: "Window Opened fires State change")

        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        WindowsManager.openNewWindow(with: Tab(content: .none))
        waitForExpectations(timeout: 0.3, handler: nil)
    }

    @MainActor
    func testWhenManyWindowsOpenedThenStateChangePublished() {
        WindowsManager.openNewWindow(with: Tab(content: .none))

        let n = 7
        let e = expect(description: "Windows Opened fire State change", events: n)

        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        for _ in (0..<n) {
            WindowsManager.openNewWindow(with: Tab(content: .none))
        }

        waitForExpectations(timeout: 0.3, handler: nil)
        cancellables.removeAll()
    }

    @MainActor
    func testWhenWindowIsClosedThenStateChangePublished() {
        let window = WindowsManager.openNewWindow(with: Tab(content: .none))

        let e = expectation(description: "Window Closed fires State changes")

        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        window!.close()
        waitForExpectations(timeout: 3, handler: nil)
    }

    @MainActor
    func testWhenWindowIsPositionedThenStateChangePublished() {
        let window = WindowsManager.openNewWindow(with: Tab(content: .none))

        let e = expectation(description: "Window setFrameOrigin fires State changes")

        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        window?.setFrameOrigin(.init(x: .random(in: 0...1000), y: .random(in: 0...1000)))

        waitForExpectations(timeout: 1, handler: nil)
    }

    @MainActor
    func testWhenWindowIsResizedThenStateChangePublished() {
        let window = WindowsManager.openNewWindow(with: Tab(content: .none))

        let e = expectation(description: "Window setContentSize fires State changes")

        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        window?.setContentSize(.init(width: .random(in: 100...1000), height: .random(in: 100...1000)))

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    @MainActor
    func testWhenNewTabIsOpenedThenStateChangePublished() {
        WindowsManager.openNewWindow(with: Tab(content: .none))
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .append(tab: Tab(content: .none))

        // 2 events should be fired (one for tab appending, one for selectionIndex change)
        let e = expect(description: "Append new tab fires State changes", events: 2)
        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        WindowControllersManager.shared.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .append(tab: Tab(content: .none))

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    @MainActor
    func testWhenTabIsClosedThenStateChangePublished() {
        WindowsManager.openNewWindow(with: Tab(content: .none))
        WindowsManager.openNewWindow(with: Tab(content: .none))
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .append(tab: Tab(content: .none))
        WindowControllersManager.shared.mainWindowControllers[1].mainViewController.tabCollectionViewModel
            .append(tab: Tab(content: .none))

        // 4 events should be fired (2 for tabs removal, 2 for selectionIndex change)
        let e = expect(description: "Close tabs fire State Changee", events: 4)
        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        WindowControllersManager.shared.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .remove(at: .unpinned(0))
        WindowControllersManager.shared.mainWindowControllers[1].mainViewController.tabCollectionViewModel
            .remove(at: .unpinned(1))

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    @MainActor
    func testWhenAllTabsExceptOneClosedThenStateChangePublished() {
        WindowsManager.openNewWindow(with: Tab(content: .none))
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .append(tab: Tab(content: .none))
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .append(tab: Tab(content: .none))
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .append(tab: Tab(content: .none))

        // 2 events should be fired (one for tab removal, one for selectionIndex change)
        let e = expect(description: "Close tabs fires State changes", events: 2)
        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        WindowControllersManager.shared.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .removeAllTabs(except: 1)

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    @MainActor
    func testWhenTabsReorderedThenStateChangePublished() {
        WindowsManager.openNewWindow(with: Tab(content: .none))
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .append(tab: Tab(content: .none))
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .append(tab: Tab(content: .none))
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .append(tab: Tab(content: .none))

        // 2 events should be fired: 1 for tabs reordering, 1 for selectionIndex change
        let e = expect(description: "Reordering tabs fires State changes", events: 2)
        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        WindowControllersManager.shared.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .moveTab(at: 2, to: 0)

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    @MainActor
    func testWhenTabURLChangedThenStateChangePublished() {
        WindowsManager.openNewWindow(with: Tab(content: .none))

        var e: XCTestExpectation? = expectation(description: "Reordering tabs fires State changes")
        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e?.fulfill()
                e = nil
            }.store(in: &cancellables)

        WindowControllersManager.shared.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .tabViewModel(at: 0)!.tab.url = URL(string: "https://duckduckgo.com")!

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    @MainActor
    func testWhenTabFaviconChangedThenStateChangePublished() {
        WindowsManager.openNewWindow(with: Tab(content: .none))

        let e = expectation(description: "Reordering tabs fires State changes")
        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        WindowControllersManager.shared.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .tabViewModel(at: 0)!.tab.favicon = NSImage()

        waitForExpectations(timeout: 0.3, handler: nil)
    }

}
