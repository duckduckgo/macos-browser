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

        // set NSApp.runType to appropriate test run type
        _=NSApplication.swizzleRunTypeOnce

        // dedicate temporary directory for tests
        _=FileManager.swizzleTemporaryDirectoryOnce

        // add code to be run on Unit Tests startup here...

    }

}

extension TestRunHelper: XCTestObservation {

    func testBundleWillStart(_ testBundle: Bundle) {

    }

    func testBundleDidFinish(_ testBundle: Bundle) {

    }

    func testSuiteWillStart(_ testSuite: XCTestSuite) {

    }

    func testSuiteDidFinish(_ testSuite: XCTestSuite) {

    }

    func testCaseWillStart(_ testCase: XCTestCase) {
        // cleanup dedicated temporary directory before each test run
        FileManager.default.cleanupTemporaryDirectory()
    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
        // cleanup dedicated temporary directory after each test run
        FileManager.default.cleanupTemporaryDirectory()
    }

}

extension NSApplication {

    static var swizzleRunTypeOnce: Void = {
        let runTypeMethod = class_getInstanceMethod(NSApplication.self, #selector(getter: NSApplication.runType))!
        let swizzledTunTypeMethod = class_getInstanceMethod(NSApplication.self, #selector(NSApplication.swizzled_runType))!

        method_exchangeImplementations(runTypeMethod, swizzledTunTypeMethod)
    }()

    @objc dynamic func swizzled_runType() -> NSApplication.RunType {
        RunType(bundle: Bundle(for: TestRunHelper.self))
    }

}

extension NSApplication.RunType {

    init(bundle: Bundle) {
        if bundle.displayName!.hasPrefix("Unit") {
            self = .unitTests
        } else if bundle.displayName!.hasPrefix("Integration") {
            self = .integrationTests
        } else {
            self = .uiTests
        }
    }

}
