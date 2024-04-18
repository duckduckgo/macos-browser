//
//  CBRCompileTimeReporterTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import PixelKit
@testable import DuckDuckGo_Privacy_Browser

class CBRCompileTimeReporterTests: XCTestCase {
    typealias Reporter = AbstractContentBlockingAssetsCompilationTimeReporter<NSObject>

    let host = "improving.duckduckgo.com"
    var tab: NSObject! = NSObject()
    var time = CACurrentMediaTime()
    let pixelKit = PixelKit(dryRun: true,
                            appVersion: "1.0.0",
                            defaultHeaders: [:],
                            defaults: UserDefaults(),
                            fireRequest: { _, _, _, _, _, _ in })

    override func setUp() {
        PixelKit.setSharedForTesting(pixelKit: pixelKit)
        UserDefaultsWrapper<Any>.clearAll()
    }

    override func tearDown() {
        HTTPStubs.removeAllStubs()
        PixelKit.tearDown()
        super.tearDown()
    }

    func initReporter(onboardingFinished: Bool) -> Reporter {
        let udWrapper = UserDefaultsWrapper(key: .onboardingFinished, defaultValue: true)
        udWrapper.wrappedValue = onboardingFinished

        let reporter = Reporter()
        reporter.currentTime = { self.time }
        return reporter
    }

    @discardableResult
    func performTest(withOnboardingFinished onboardingFinished: Bool,
                     waitTime: TimeInterval,
                     expectedWaitTime: GeneralPixel.CompileRulesWaitTime,
                     result: GeneralPixel.WaitResult,
                     runBeforeFinishing: ((Reporter) throws -> Void)? = nil) rethrows -> Reporter {

        HTTPStubs.removeAllStubs()
        defer {
            HTTPStubs.removeAllStubs()
        }
        let reporter = initReporter(onboardingFinished: onboardingFinished)
        let pixel = GeneralPixel.compileRulesWait(onboardingShown: onboardingFinished ? .regularNavigation : .onboardingShown,
                                                 waitTime: expectedWaitTime,
                                                 result: result)

        reporter.tabWillWaitForRulesCompilation(tab)

        let expectation = expectation(description: "Pixel should fire")
        stub(condition: isHost(host)) { req -> HTTPStubsResponse in
            print("received", req.url?.lastPathComponent ?? "", "expected", pixel.name)
            XCTAssertEqual(req.url?.lastPathComponent, pixel.name, "waitTime \(waitTime)")
            expectation.fulfill()
            return HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        do {
            try runBeforeFinishing?(reporter)
        } catch {
            expectation.fulfill()
            waitForExpectations(timeout: 0)
            throw error
        }

        time += waitTime
        switch result {
        case .success:
            reporter.reportWaitTimeForTabFinishedWaitingForRules(tab)
        case .closed:
            reporter.tabWillClose(tab)
        case .quit:
            NotificationCenter.default.post(Notification(name: NSApplication.willTerminateNotification,
                                                         object: NSApp,
                                                         userInfo: nil))
        }

        waitForExpectations(timeout: 5)
        return reporter
    }

    typealias Pair = (TimeInterval, GeneralPixel.CompileRulesWaitTime)
    let waitExpectationSeq: [Pair] = [(0, .noWait),
                                      (0.5, .lessThan1s),
                                      (1, .lessThan1s),
                                      (2, .lessThan5s),
                                      (4.5, .lessThan5s),
                                      (6, .lessThan10s),
                                      (9.5, .lessThan10s),
                                      (19.5, .lessThan20s),
                                      (21, .lessThan40s),
                                      (39.5, .lessThan40s),
                                      (41, .more),
                                      (60, .more)]

    func testWhenWaitingSucceedsDuringOnboardingThenPixelIsFired() {
        for (time, expectation) in waitExpectationSeq {
            autoreleasepool {
                _=performTest(withOnboardingFinished: false, waitTime: time, expectedWaitTime: expectation, result: .success)
            }
        }
    }

    func testWaitingSucceedsDuringRegularNavigation() {
        for (time, expectation) in waitExpectationSeq {
            autoreleasepool {
                _=performTest(withOnboardingFinished: true, waitTime: time, expectedWaitTime: expectation, result: .success)
            }
        }
    }

    func testWhenTabClosedDuringOnboardingThenPixelIsFired() {
        for (time, expectation) in waitExpectationSeq {
            autoreleasepool {
                _=performTest(withOnboardingFinished: false, waitTime: time, expectedWaitTime: expectation, result: .closed)
            }
        }
    }

    func testWhenTabClosedDuringRegularNavigationThenPixelIsFired() {
        for (time, expectation) in waitExpectationSeq {
            autoreleasepool {
                _=performTest(withOnboardingFinished: true, waitTime: time, expectedWaitTime: expectation, result: .closed)
            }
        }
    }

    func testWhenAppQuitsDuringOnboardingThenPixelIsFired() {
        for (time, expectation) in waitExpectationSeq {
            autoreleasepool {
                _=performTest(withOnboardingFinished: false, waitTime: time, expectedWaitTime: expectation, result: .quit)
            }
        }
    }

    func testWhenAppQuitsDuringRegularNavigationThenPixelIsFired() {
        for (time, expectation) in waitExpectationSeq {
            autoreleasepool {
                _=performTest(withOnboardingFinished: true, waitTime: time, expectedWaitTime: expectation, result: .quit)
            }
        }
    }

    func testWhenReporterReceivesEventSequenceThenOnlyOnePixelIsFired() {
        let reporter = performTest(withOnboardingFinished: true, waitTime: 1, expectedWaitTime: .lessThan1s, result: .success)

        stub(condition: isHost(host)) { _ -> HTTPStubsResponse in
            XCTFail("Unexpected Pixel")
            return HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        reporter.tabWillClose(tab)
        NotificationCenter.default.post(Notification(name: NSApplication.willTerminateNotification,
                                                     object: NSApp,
                                                     userInfo: nil))
    }

    func testWhenMoreThanOneTabWaitThenOnlyOnePixelIsFiredAndTabsDeallocated() {
        weak var tab1 = self.tab
        weak var tab2: NSObject!
        weak var tab3: NSObject!

        autoreleasepool {
            let t2 = NSObject()
            let t3 = NSObject()
            tab2 = t2
            tab3 = t3

            performTest(withOnboardingFinished: false, waitTime: 4, expectedWaitTime: .lessThan5s, result: .success) { reporter in
                self.time += 4
                reporter.tabWillWaitForRulesCompilation(tab2)
                reporter.tabWillWaitForRulesCompilation(tab3)
                reporter.reportWaitTimeForTabFinishedWaitingForRules(tab3)
                reporter.tabWillClose(tab2)
            }

            self.tab = nil
        }

        XCTAssertNil(tab1)
        XCTAssertNil(tab2)
        XCTAssertNil(tab3)
    }

    func testWhenNoWaitIsPerformedAndMoreThanOneTabWaitThenOnlyNoWaitPixelIsFired() {
        weak var tab1 = self.tab
        weak var tab2: NSObject!
        weak var tab3: NSObject!

        autoreleasepool {
            let t2 = NSObject()
            let t3 = NSObject()
            tab2 = t2
            tab3 = t3

            performTest(withOnboardingFinished: false, waitTime: 4, expectedWaitTime: .noWait, result: .success) { reporter in
                reporter.reportNavigationDidNotWaitForRules()
                reporter.tabWillWaitForRulesCompilation(tab2)
                reporter.tabWillWaitForRulesCompilation(tab3)
                reporter.reportWaitTimeForTabFinishedWaitingForRules(tab3)
                reporter.tabWillClose(tab2)
            }

            self.tab = nil
        }

        XCTAssertNil(tab1)
        XCTAssertNil(tab2)
        XCTAssertNil(tab3)
    }

    func testWhenTabDisappearsWithoutTabWillCloseItIsDeallocated() {
        weak var tab1 = self.tab

        struct Err: Error {}
        autoreleasepool {
            try? _=performTest(withOnboardingFinished: false, waitTime: 4, expectedWaitTime: .lessThan5s, result: .success) { _ in
                self.tab = nil
                throw Err()
            }
        }
        XCTAssertNil(tab1)

    }

}
