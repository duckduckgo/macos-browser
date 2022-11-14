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

final class DeallocationTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        assert(WindowControllersManager.shared.mainWindowControllers.isEmpty)
        TestsDependencyProvider<Tab>.setUp {
            $0.faviconManagement = FaviconManagerMock()
            $0.useDefault(for: \.privatePlayer)
            $0.useDefault(for: \.windowControllersManager)
            $0.extensionsBuilder = TestTabExtensionsBuilder()
        }
    }

    override func tearDown() {
        WindowsManager.closeWindows()
        for controller in WindowControllersManager.shared.mainWindowControllers {
            WindowControllersManager.shared.unregister(controller)
        }
        TestsDependencyProvider<Tab>.reset()
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
                WindowControllersManager.shared.mainWindowControllers[i].mainViewController.tabCollectionViewModel
                    .appendNewTab()

                expectDeallocation(of: WindowControllersManager.shared.mainWindowControllers[i])
                expectDeallocation(of: WindowControllersManager.shared.mainWindowControllers[i].mainViewController)

                expectDeallocation(of: WindowControllersManager.shared.mainWindowControllers[i].mainViewController.tabBarViewController)
                expectDeallocation(of: WindowControllersManager.shared.mainWindowControllers[i].mainViewController.navigationBarViewController)
                expectDeallocation(of: WindowControllersManager.shared.mainWindowControllers[i].mainViewController.browserTabViewController)
                expectDeallocation(of: WindowControllersManager.shared.mainWindowControllers[i].mainViewController.findInPageViewController)
                expectDeallocation(of: WindowControllersManager.shared.mainWindowControllers[i].mainViewController.fireViewController)

                expectDeallocation(of: WindowControllersManager.shared.mainWindowControllers[i].mainViewController.tabCollectionViewModel)
                for tab in WindowControllersManager.shared.mainWindowControllers[i].mainViewController.tabCollectionViewModel.tabCollection.tabs {
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
