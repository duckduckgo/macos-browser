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

class AppStateChangePublisherTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        assert(WindowControllersManager.shared.mainWindowControllers.isEmpty)
    }

    override func tearDown() {
        cancellables.removeAll()
        WindowsManager.closeWindows()
        for controller in WindowControllersManager.shared.mainWindowControllers {
            WindowControllersManager.shared.unregister(controller)
        }
    }

    // MARK: -

    func testWhenPublisherInitiatedNoStateChangeEventsPublished() {
        WindowsManager.openNewWindow()

        WindowControllersManager.shared.stateChanged
            .sink { _ in
                XCTFail("Should not receive initial State Change")
            }.store(in: &cancellables)

        let e = expectation(description: "Wait 0.1sec")
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            e.fulfill()
        }
        withExtendedLifetime(timer) {
            waitForExpectations(timeout: 10.0, handler: nil)
        }
    }

    func testWhenWindowIsOpenedThenStateChangePublished() {
        let e = expectation(description: "Window Opened fires State change")

        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        WindowsManager.openNewWindow()
        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenManyWindowsOpenedThenStateChangePublished() {
        WindowsManager.openNewWindow()

        let n = 15
        var counter: Int!
        let expectations = (0..<n).map { expectation(description: "Window \($0) Opened fires State change") }

        WindowControllersManager.shared.stateChanged
            .sink { _ in
                expectations[counter].fulfill()
            }.store(in: &cancellables)

        for i in (0..<n) {
            counter = i
            WindowsManager.openNewWindow()
        }

        waitForExpectations(timeout: 0.3, handler: nil)
        XCTAssertEqual(counter, n - 1)
    }

    func testWhenWindowIsClosedThenStateChangePublished() {
        let window = WindowsManager.openNewWindow()

        let e = expectation(description: "Window Closed fires State changes")

        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        window!.close()
        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenWindowIsPositionedThenStateChangePublished() {
        let window = WindowsManager.openNewWindow()

        let e = expectation(description: "Window setFrameOrigin fires State changes")

        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        window?.setFrameOrigin(.init(x: .random(in: 0...1000), y: .random(in: 0...1000)))

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenWindowIsResizedThenStateChangePublished() {
        let window = WindowsManager.openNewWindow()

        let e = expectation(description: "Window setContentSize fires State changes")

        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        window?.setContentSize(.init(width: .random(in: 100...1000), height: .random(in: 100...1000)))

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenNewTabIsOpenedThenStateChangePublished() {
        WindowsManager.openNewWindow()
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController!.tabCollectionViewModel
            .appendNewTab()

        let e = expectation(description: "Append new tab fires State changes")
        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        WindowControllersManager.shared.mainWindowControllers[0].mainViewController!.tabCollectionViewModel
            .appendNewTab()

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenTabIsClosedThenStateChangePublished() {
        WindowsManager.openNewWindow()
        WindowsManager.openNewWindow()
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController!.tabCollectionViewModel
            .appendNewTab()
        WindowControllersManager.shared.mainWindowControllers[1].mainViewController!.tabCollectionViewModel
            .appendNewTab()

        var counter = 0
        let e1 = expectation(description: "Close tab 1 fires State change")
        let e2 = expectation(description: "Close tab 2 fires State changes")
        WindowControllersManager.shared.stateChanged
            .sink { _ in
                switch counter {
                case 0:
                    e1.fulfill()
                default:
                    e2.fulfill()
                }
                counter += 1
            }.store(in: &cancellables)

        WindowControllersManager.shared.mainWindowControllers[0].mainViewController!.tabCollectionViewModel
            .remove(at: 0)
        WindowControllersManager.shared.mainWindowControllers[1].mainViewController!.tabCollectionViewModel
            .remove(at: 1)

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenAllTabsExceptOneClosedThenStateChangePublished() {
        WindowsManager.openNewWindow()
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController!.tabCollectionViewModel
            .appendNewTab()
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController!.tabCollectionViewModel
            .appendNewTab()
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController!.tabCollectionViewModel
            .appendNewTab()

        let e = expectation(description: "Close tabs fires State changes")
        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        WindowControllersManager.shared.mainWindowControllers[0].mainViewController!.tabCollectionViewModel
            .removeAllTabs(except: 1)

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenTabsReorderedThenStateChangePublished() {
        WindowsManager.openNewWindow()
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController!.tabCollectionViewModel
            .appendNewTab()
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController!.tabCollectionViewModel
            .appendNewTab()
        WindowControllersManager.shared.mainWindowControllers[0].mainViewController!.tabCollectionViewModel
            .appendNewTab()

        let e = expectation(description: "Reordering tabs fires State changes")
        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        WindowControllersManager.shared.mainWindowControllers[0].mainViewController!.tabCollectionViewModel
            .moveTab(at: 2, to: 0)

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testWhenTabURLChangedThenStateChangePublished() {
        WindowsManager.openNewWindow()

        let e = expectation(description: "Reordering tabs fires State changes")
        WindowControllersManager.shared.stateChanged
            .sink { _ in
                e.fulfill()
            }.store(in: &cancellables)

        WindowControllersManager.shared.mainWindowControllers[0].mainViewController!.tabCollectionViewModel
            .tabViewModel(at: 0)!.tab.url = URL(string: "https://duckduckgo.com")

        waitForExpectations(timeout: 0.3, handler: nil)
    }

}
