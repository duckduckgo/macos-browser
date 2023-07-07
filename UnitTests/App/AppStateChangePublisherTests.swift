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

import XCTest
import Combine
@testable import DuckDuckGo_Privacy_Browser

@MainActor
final class AppStateChangePublisherTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    var windowManager: WindowManagerProtocol!

    override func setUp() {
        windowManager = WindowManager(dependencyProvider: dependencies(for: WindowManager.self)) { _ in
            dependencies(for: AbstractWindowManagerNestedDependencies.self)
        }
        assert(windowManager.mainWindowControllers.isEmpty)
        TestDependencyProvider.set(windowManager, for: \MainWindowController.windowManager)
    }

    override func tearDown() {
        cancellables.removeAll()
        windowManager.closeWindows()
        for controller in windowManager.mainWindowControllers {
            windowManager.unregister(controller)
        }
        windowManager = nil
    }

    final class MultiExpectation {
        let e: XCTestExpectation
        let count: Int
        var counter = 0

        init(e: XCTestExpectation, count: Int) {
            self.e = e
            self.count = count
        }

        func fulfill() {
            counter += 1
            if counter >= count {
                e.fulfill()
            }
        }
    }

    func expect(description expectationDescription: String, events: Int) -> MultiExpectation {
        MultiExpectation(e: expectation(description: description), count: events)
    }

    // MARK: -

    func testWhenWindowIsOpenedThenStateChangePublished() {
        let e = expectation(description: "Window Opened fires State change")

        windowManager.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        windowManager.openNewWindow()
        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenManyWindowsOpenedThenStateChangePublished() {
        windowManager.openNewWindow()

        let n = 7
        let e = expect(description: "Windows Opened fire State change", events: n)

        windowManager.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        for _ in (0..<n) {
            windowManager.openNewWindow()
        }

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenWindowIsClosedThenStateChangePublished() {
        let window = windowManager.openNewWindow()

        let e = expectation(description: "Window Closed fires State changes")

        windowManager.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        window!.close()
        waitForExpectations(timeout: 3, handler: nil)
    }

    func testWhenWindowIsPositionedThenStateChangePublished() {
        let window = windowManager.openNewWindow()

        let e = expectation(description: "Window setFrameOrigin fires State changes")

        windowManager.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        window?.setFrameOrigin(.init(x: .random(in: 0...1000), y: .random(in: 0...1000)))

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testWhenWindowIsResizedThenStateChangePublished() {
        let window = windowManager.openNewWindow()

        let e = expectation(description: "Window setContentSize fires State changes")

        windowManager.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        window?.setContentSize(.init(width: .random(in: 100...1000), height: .random(in: 100...1000)))

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenNewTabIsOpenedThenStateChangePublished() {
        windowManager.openNewWindow()
        windowManager.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .appendNewTab()

        // 2 events should be fired (one for tab appending, one for selectionIndex change)
        let e = expect(description: "Append new tab fires State changes", events: 2)
        windowManager.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        windowManager.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .appendNewTab()

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenTabIsClosedThenStateChangePublished() {
        windowManager.openNewWindow()
        windowManager.openNewWindow()
        windowManager.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .appendNewTab()
        windowManager.mainWindowControllers[1].mainViewController.tabCollectionViewModel
            .appendNewTab()

        // 4 events should be fired (2 for tabs removal, 2 for selectionIndex change)
        let e = expect(description: "Close tabs fire State Changee", events: 4)
        windowManager.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        windowManager.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .remove(at: .unpinned(0))
        windowManager.mainWindowControllers[1].mainViewController.tabCollectionViewModel
            .remove(at: .unpinned(1))

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenAllTabsExceptOneClosedThenStateChangePublished() {
        windowManager.openNewWindow()
        windowManager.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .appendNewTab()
        windowManager.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .appendNewTab()
        windowManager.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .appendNewTab()

        // 2 events should be fired (one for tab removal, one for selectionIndex change)
        let e = expect(description: "Close tabs fires State changes", events: 2)
        windowManager.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        windowManager.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .removeAllTabs(except: 1)

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenTabsReorderedThenStateChangePublished() {
        windowManager.openNewWindow()
        windowManager.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .appendNewTab()
        windowManager.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .appendNewTab()
        windowManager.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .appendNewTab()

        // 2 events should be fired: 1 for tabs reordering, 1 for selectionIndex change
        let e = expect(description: "Reordering tabs fires State changes", events: 2)
        windowManager.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        windowManager.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .moveTab(at: 2, to: 0)

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenTabURLChangedThenStateChangePublished() {
        windowManager.openNewWindow()

        var e: XCTestExpectation? = expectation(description: "Reordering tabs fires State changes")
        windowManager.stateChanged
            .sink { _ in
                e?.fulfill()
                e = nil
            }.store(in: &cancellables)

        windowManager.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .tabViewModel(at: 0)!.tab.url = URL(string: "https://duckduckgo.com")

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenTabFaviconChangedThenStateChangePublished() {
        windowManager.openNewWindow()

        let e = expectation(description: "Reordering tabs fires State changes")
        windowManager.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        windowManager.mainWindowControllers[0].mainViewController.tabCollectionViewModel
            .tabViewModel(at: 0)!.tab.favicon = NSImage()

        waitForExpectations(timeout: 0.3, handler: nil)
    }

}

private extension Tab {

    var url: URL? {
        get {
            content.url
        }
        set {
            setContent(newValue.map { TabContent.url($0) } ?? .homePage)
        }
    }
    
}
