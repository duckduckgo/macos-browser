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
@testable import DuckDuckGo_Privacy_Browser

class CBRCompileTimeReporterTests: XCTestCase {

    let host = "improving.duckduckgo.com"
    var reporter: AbstractContentBlockingAssetsCompilationTimeReporter<NSObject>!
    var tab: NSObject! = NSObject()
    var time = CACurrentMediaTime()

    override func setUp() {
        Pixel.setUp()
        UserDefaultsWrapper<Any>.clearAll()
    }

    override func tearDown() {
        HTTPStubs.removeAllStubs()
        Pixel.tearDown()
        super.tearDown()
    }

    func initReporter(onboardingFinished: Bool) {
        var udWrapper = UserDefaultsWrapper(key: .onboardingFinished, defaultValue: true)
        udWrapper.wrappedValue = onboardingFinished

        reporter = AbstractContentBlockingAssetsCompilationTimeReporter<NSObject>()
        reporter.currentTime = { self.time }
    }

    func performTest(withOnboardingFinished onboardingFinished: Bool,
                     waitTime: TimeInterval,
                     expectedWaitTime: Pixel.Event.CompileRulesWaitTime,
                     result: Pixel.Event.WaitResult,
                     runBeforeFinishing: ((AbstractContentBlockingAssetsCompilationTimeReporter<NSObject>) throws -> Void)? = nil) rethrows {

        HTTPStubs.removeAllStubs()
        initReporter(onboardingFinished: onboardingFinished)
        let pixel = Pixel.Event.compileRulesWait(onboardingShown: onboardingFinished ? .regularNavigation : .onboardingShown,
                                                 waitTime: expectedWaitTime,
                                                 result: result)

        reporter.tabWillWaitForRulesCompilation(tab)

        let expectation = expectation(description: "Pixel should fire")
        stub(condition: isHost(host)) { req -> HTTPStubsResponse in
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

        waitForExpectations(timeout: 1)
    }

    typealias Pair = (TimeInterval, Pixel.Event.CompileRulesWaitTime)
    let waitExpectationSeq: [Pair] = [(0, .noWait),
                                      (0.5, .lessThan1s),
                                      (0.1, .lessThan1s),
                                      (2, .lessThan5s),
                                      (5, .lessThan5s),
                                      (6, .lessThan10s),
                                      (10, .lessThan10s),
                                      (20, .lessThan20s),
                                      (21, .lessThan40s),
                                      (40, .lessThan40s),
                                      (41, .more),
                                      (60, .more)]

    func testWhenWaitingSucceedsDuringOnboardingThenPixelIsFired() {
        for (time, expectation) in waitExpectationSeq {
            performTest(withOnboardingFinished: false, waitTime: time, expectedWaitTime: expectation, result: .success)
        }
    }

    func testWaitingSucceedsDuringRegularNavigation() {
        for (time, expectation) in waitExpectationSeq {
            performTest(withOnboardingFinished: true, waitTime: time, expectedWaitTime: expectation, result: .success)
        }
    }

    func testWhenTabClosedDuringOnboardingThenPixelIsFired() {
        for (time, expectation) in waitExpectationSeq {
            performTest(withOnboardingFinished: false, waitTime: time, expectedWaitTime: expectation, result: .closed)
        }
    }

    func testWhenTabClosedDuringRegularNavigationThenPixelIsFired() {
        for (time, expectation) in waitExpectationSeq {
            performTest(withOnboardingFinished: true, waitTime: time, expectedWaitTime: expectation, result: .closed)
        }
    }

    func testWhenAppQuitsDuringOnboardingThenPixelIsFired() {
        for (time, expectation) in waitExpectationSeq {
            performTest(withOnboardingFinished: false, waitTime: time, expectedWaitTime: expectation, result: .quit)
        }
    }

    func testWhenAppQuitsDuringRegularNavigationThenPixelIsFired() {
        for (time, expectation) in waitExpectationSeq {
            performTest(withOnboardingFinished: true, waitTime: time, expectedWaitTime: expectation, result: .quit)
        }
    }

    func testWhenReporterReceivesEventSequenceThenOnlyOnePixelIsFired() {
        performTest(withOnboardingFinished: true, waitTime: 1, expectedWaitTime: .lessThan1s, result: .success)

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
            try? performTest(withOnboardingFinished: false, waitTime: 4, expectedWaitTime: .lessThan5s, result: .success) { _ in
                self.tab = nil
                throw Err()
            }
        }
        XCTAssertNil(tab1)
        
    }

}
