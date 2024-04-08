//
//  TestRunHelper.swift
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

import Foundation
import XCTest
@testable import DuckDuckGo_Privacy_Browser

@objc(TestRunHelper)
final class TestRunHelper: NSObject {
    @objc(sharedInstance) static let shared = TestRunHelper()

    override init() {
        super.init()
        XCTestObservationCenter.shared.addTestObserver(self)

        // allow mocking NSApp.currentEvent
        _=NSApplication.swizzleCurrentEventOnce

        // dedicate temporary directory for tests
        _=FileManager.swizzleTemporaryDirectoryOnce
        FileManager.default.cleanupTemporaryDirectory()

        // provide extra info on failures
        _=NSError.swizzleLocalizedDescriptionOnce

        // add code to be run on Unit Tests startup here...

    }

}

extension TestRunHelper: XCTestObservation {

    func testBundleWillStart(_ testBundle: Bundle) {

    }

    func testBundleDidFinish(_ testBundle: Bundle) {
        if case .integrationTests = NSApp.runType {
            FileManager.default.cleanupTemporaryDirectory(excluding: ["Database.sqlite",
                                                                      "Database.sqlite-wal",
                                                                      "Database.sqlite-shm"])
        }
    }

    func testSuiteWillStart(_ testSuite: XCTestSuite) {

    }

    func testSuiteDidFinish(_ testSuite: XCTestSuite) {

    }

    func testCaseWillStart(_ testCase: XCTestCase) {
        if case .unitTests = NSApp.runType {
            // cleanup dedicated temporary directory before each test run
            FileManager.default.cleanupTemporaryDirectory()
            NSAnimationContext.current.duration = 0
        }
        NSApp.swizzled_currentEvent = nil
    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
        if case .unitTests = NSApp.runType {
            // cleanup dedicated temporary directory after each test run
            FileManager.default.cleanupTemporaryDirectory()
        }
        NSApp.swizzled_currentEvent = nil
    }

}

extension NSApplication {

    // allow mocking NSApp.currentEvent

    static var swizzleCurrentEventOnce: Void = {
        let curentEventMethod = class_getInstanceMethod(NSApplication.self, #selector(getter: NSApplication.currentEvent))!
        let swizzledCurentEventMethod = class_getInstanceMethod(NSApplication.self, #selector(getter: NSApplication.swizzled_currentEvent))!

        method_exchangeImplementations(curentEventMethod, swizzledCurentEventMethod)
    }()

    private static let currentEventKey = UnsafeRawPointer(bitPattern: "currentEventKey".hashValue)!
    @objc dynamic var swizzled_currentEvent: NSEvent? {
        get {
            objc_getAssociatedObject(self, Self.currentEventKey) as? NSEvent
                ?? self.swizzled_currentEvent // call original
        }
        set {
            objc_setAssociatedObject(self, Self.currentEventKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

}
