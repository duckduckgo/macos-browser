//
//  DeallocationTests.swift
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
final class DeallocationTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        assert(WindowManager.shared.mainWindowControllers.isEmpty)
    }

    override func tearDown() {
        WindowsManager.closeWindows()
        for controller in WindowManager.shared.mainWindowControllers {
            WindowManager.shared.unregister(controller)
        }
    }

    class DeallocationTracker {
        let e: XCTestExpectation
        init(e: XCTestExpectation) {
            self.e = e
        }
        deinit {
            e.fulfill()
        }
    }

    static let deallocationTrackerKey = UnsafeRawPointer(bitPattern: "DeallocationTrackerKey".hashValue)!
    func expectDeallocation(of object: NSObject) {
        let tracker = DeallocationTracker(e: expectation(description: "\(object) should deallocate"))
        objc_setAssociatedObject(object, Self.deallocationTrackerKey, tracker, .OBJC_ASSOCIATION_RETAIN)
    }

    // MARK: -

    func testWindowsDeallocation() {
        autoreleasepool {

            // `showWindow: false` would still open a window, but not activate it, which seems to upset CI
            weak var window1: NSWindow! = WindowsManager.openNewWindow(showWindow: false)
            weak var window2: NSWindow! = WindowsManager.openNewWindow(showWindow: false)

            for i in 0...1 {
                WindowManager.shared.mainWindowControllers[i].mainViewController.tabCollectionViewModel
                    .appendNewTab()

                expectDeallocation(of: WindowManager.shared.mainWindowControllers[i])
                expectDeallocation(of: WindowManager.shared.mainWindowControllers[i].mainViewController)

                expectDeallocation(of: WindowManager.shared.mainWindowControllers[i].mainViewController.tabBarViewController)
                expectDeallocation(of: WindowManager.shared.mainWindowControllers[i].mainViewController.navigationBarViewController)
                expectDeallocation(of: WindowManager.shared.mainWindowControllers[i].mainViewController.browserTabViewController)
                expectDeallocation(of: WindowManager.shared.mainWindowControllers[i].mainViewController.findInPageViewController)
                expectDeallocation(of: WindowManager.shared.mainWindowControllers[i].mainViewController.fireViewController)

                expectDeallocation(of: WindowManager.shared.mainWindowControllers[i].mainViewController.tabCollectionViewModel)
                for tab in WindowManager.shared.mainWindowControllers[i].mainViewController.tabCollectionViewModel.tabCollection.tabs {
                    expectDeallocation(of: tab)
                    expectDeallocation(of: tab.webView)
                }
            }

            window1.close()
            window2.close()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

}
