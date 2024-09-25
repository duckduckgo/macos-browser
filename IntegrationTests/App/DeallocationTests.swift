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
    var animationDuration: TimeInterval = 0

    @MainActor
    override func setUp() {
        assert(WindowControllersManager.shared.mainWindowControllers.isEmpty)
        animationDuration = NSAnimationContext.current.duration
        NSAnimationContext.current.duration = 0
    }

    @MainActor
    override func tearDown() {
        WindowsManager.closeWindows()
        for controller in WindowControllersManager.shared.mainWindowControllers {
            WindowControllersManager.shared.unregister(controller)
        }
        NSAnimationContext.current.duration = animationDuration
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

    @MainActor
    func testWindowsDeallocation() {
        autoreleasepool {

            // `showWindow: false` would still open a window, but not activate it, which seems to upset CI
            WindowsManager.openNewWindow()
            WindowsManager.openNewWindow(with: .duckDuckGo, source: .ui, isBurner: false)
            WindowsManager.openNewWindow(with: .duckDuckGo, source: .ui, isBurner: true)

            for i in 0..<WindowControllersManager.shared.mainWindowControllers.count {
                WindowControllersManager.shared.mainWindowControllers[i].mainViewController.tabCollectionViewModel
                    .appendNewTab()

                expectDeallocation(of: WindowControllersManager.shared.mainWindowControllers[i])
                expectDeallocation(of: WindowControllersManager.shared.mainWindowControllers[i].window!)
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

            for wc in WindowControllersManager.shared.mainWindowControllers {
                wc.window!.close()
            }

            repeat {
                RunLoop.main.run(until: Date() + 0.1)
            } while WindowControllersManager.shared.mainWindowControllers.contains(where: { $0.window?.isVisible == true })
        }
        waitForExpectations(timeout: 5, handler: nil)
    }

    @MainActor
    func testWhenLastTabClosed_windowIsDeallocated() {
        autoreleasepool {

            // `showWindow: false` would still open a window, but not activate it, which seems to upset CI
            WindowsManager.openNewWindow()
            WindowsManager.openNewWindow(with: .duckDuckGo, source: .ui, isBurner: false)
            WindowsManager.openNewWindow(with: .duckDuckGo, source: .ui, isBurner: true)

            for i in 0..<WindowControllersManager.shared.mainWindowControllers.count {
                WindowControllersManager.shared.mainWindowControllers[i].mainViewController.tabCollectionViewModel
                    .appendNewTab()

                expectDeallocation(of: WindowControllersManager.shared.mainWindowControllers[i])
                expectDeallocation(of: WindowControllersManager.shared.mainWindowControllers[i].window!)
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

            for i in (0..<WindowControllersManager.shared.mainWindowControllers.count).reversed() {
                for _ in 0..<WindowControllersManager.shared.mainWindowControllers[i].mainViewController.tabCollectionViewModel.tabCollection.tabs.count {
                    WindowControllersManager.shared.mainWindowControllers[i].mainViewController.closeTab(self)
                }
            }

            repeat {
                RunLoop.main.run(until: Date() + 0.1)
            } while WindowControllersManager.shared.mainWindowControllers.contains(where: { $0.window?.isVisible == true })
        }
        waitForExpectations(timeout: 5, handler: nil)
    }

}
