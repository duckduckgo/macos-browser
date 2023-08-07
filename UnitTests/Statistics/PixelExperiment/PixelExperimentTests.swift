//
//  PixelTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class PixelExperimentTests: XCTestCase {

    override func setUp() {
        super.setUp()
        PixelExperimentLogic { _ in }.reset()
    }

    func testWhenNotInstalledThenCohortIsNill() {
        let logic = PixelExperimentLogic { _ in }
        XCTAssertNil(logic.cohort)
    }

    func testWhenSecondInteractionWithBookmarksBarOnDayThenCorrectPixelFired() {
        let logic = PixelExperimentLogic { _ in }

        assertWhenSecondInteractionWithBookmarksBarOnDayThenNoPixelFired(0)
        logic.reset()

        assertWhenSecondInteractionWithBookmarksBarOnDayThenNoPixelFired(1)
        logic.reset()

        assertWhenSecondInteractionWithBookmarksBarOnDayThenPixelFired(2)
        logic.reset()

        assertWhenSecondInteractionWithBookmarksBarOnDayThenPixelFired(3)
        logic.reset()

        assertWhenSecondInteractionWithBookmarksBarOnDayThenPixelFired(4)
        logic.reset()

        assertWhenSecondInteractionWithBookmarksBarOnDayThenPixelFired(5)
        logic.reset()

        assertWhenSecondInteractionWithBookmarksBarOnDayThenPixelFired(6)
        logic.reset()

        assertWhenSecondInteractionWithBookmarksBarOnDayThenPixelFired(7)
        logic.reset()

        assertWhenSecondInteractionWithBookmarksBarOnDayThenPixelFired(8)
        logic.reset()

        assertWhenSecondInteractionWithBookmarksBarOnDayThenNoPixelFired(9)
        logic.reset()

        assertWhenSecondInteractionWithBookmarksBarOnDayThenNoPixelFired(10)
        logic.reset()
    }

    func testWhenFirstInteractionWithBookmarksBarThenCorrectPixelFired() {
        var pixelEvent: Pixel.Event?
        let logic = PixelExperimentLogic {
            pixelEvent = $0
        }
        logic.install()
        _ = logic.cohort

        logic.fireBookmarksBarInteractionPixel()
        if case .bookmarksBarOnboardingFirstInteraction(let cohort) = pixelEvent {
            XCTAssertEqual(cohort, logic.allocatedCohort)
        } else {
            XCTFail("Unexpected pixel")
        }
    }

    func testWhenDay4to8ThenSearchPixelSentWithCorrectCohort() {
        let logic = PixelExperimentLogic { _ in }

        assertSearchPixelNotSentWhenEnrolledDaysAgo(0)
        logic.reset()

        assertSearchPixelNotSentWhenEnrolledDaysAgo(1)
        logic.reset()

        assertSearchPixelNotSentWhenEnrolledDaysAgo(2)
        logic.reset()

        assertSearchPixelNotSentWhenEnrolledDaysAgo(3)
        logic.reset()

        assertSearchPixelSentWhenEnrolledDaysAgo(4)
        logic.reset()

        assertSearchPixelSentWhenEnrolledDaysAgo(5)
        logic.reset()

        assertSearchPixelSentWhenEnrolledDaysAgo(6)
        logic.reset()

        assertSearchPixelSentWhenEnrolledDaysAgo(7)
        logic.reset()

        assertSearchPixelSentWhenEnrolledDaysAgo(8)
        logic.reset()

        assertSearchPixelNotSentWhenEnrolledDaysAgo(9)
        logic.reset()

        assertSearchPixelNotSentWhenEnrolledDaysAgo(10)
        logic.reset()
    }

    func testWhenSubsequentAccessThenNoAllocationOccursAndNoPixelFired() {
        var pixelEvent: Pixel.Event?
        let logic = PixelExperimentLogic {
            pixelEvent = $0
        }
        logic.install()
        let originalCohort = logic.cohort

        pixelEvent = nil
        let newCohort = logic.cohort

        XCTAssertNil(pixelEvent)
        XCTAssertEqual(originalCohort, newCohort)
    }

    func testWhenFirstAccessedThenAllocationOccursAndPixelFired() {
        var pixelEvent: Pixel.Event?
        let logic = PixelExperimentLogic {
            pixelEvent = $0
        }
        logic.install()
        XCTAssertNil(logic.allocatedCohort)
        XCTAssertNil(pixelEvent)
        _ = logic.cohort
        XCTAssertNotNil(logic.allocatedCohort)
        XCTAssertNotNil(pixelEvent)

        if case .bookmarksBarOnboardingEnrollment(let cohort) = pixelEvent {
            XCTAssertEqual(cohort, logic.allocatedCohort)
        } else {
            XCTFail("Unexpected pixel")
        }
    }

    func testWhenNoCohortThenPixelsNotSent() {
        var pixelEvent: Pixel.Event?
        let logic = PixelExperimentLogic {
            pixelEvent = $0
        }
        logic.install()
        logic.fireEnrollmentPixel()
        logic.fireSearchOnDay4to8Pixel()
        logic.fireBookmarksBarInteractionPixel()
        XCTAssertNil(pixelEvent)
    }

    func assertSearchPixelSentWhenEnrolledDaysAgo(_ daysAgo: Int, file: StaticString = #file, line: UInt = #line) {
        var pixelEvent: Pixel.Event?
        let logic = PixelExperimentLogic {
            pixelEvent = $0
        }
        logic.install()
        _ = logic.cohort
        logic.enrollmentDate = Date.daysAgo(daysAgo)
        pixelEvent = nil

        logic.fireSearchOnDay4to8Pixel()

        if case .bookmarksBarOnboardingSearched4to8days(let cohort) = pixelEvent {
            XCTAssertEqual(cohort, logic.allocatedCohort)
        } else {
            XCTFail("Unexpected pixel \(String(describing: pixelEvent))", file: file, line: line)
        }
    }

    func assertSearchPixelNotSentWhenEnrolledDaysAgo(_ daysAgo: Int, file: StaticString = #file, line: UInt = #line) {
        var pixelEvent: Pixel.Event?
        let logic = PixelExperimentLogic {
            pixelEvent = $0
        }
        logic.install()
        _ = logic.cohort
        pixelEvent = nil

        logic.enrollmentDate = Date.daysAgo(daysAgo)

        logic.fireSearchOnDay4to8Pixel()
        XCTAssertNil(pixelEvent, file: file, line: line)
    }

    func assertWhenSecondInteractionWithBookmarksBarOnDayThenPixelFired(_ daysAgo: Int, file: StaticString = #file, line: UInt = #line) {
        var pixelEvent: Pixel.Event?
        let logic = PixelExperimentLogic {
            pixelEvent = $0
        }
        logic.install()
        _ = logic.cohort
        logic.enrollmentDate = Date.daysAgo(daysAgo)

        logic.fireBookmarksBarInteractionPixel()
        pixelEvent = nil
        logic.fireBookmarksBarInteractionPixel()

        if case .bookmarksBarOnboardingInteraction2to8days(let cohort) = pixelEvent {
            XCTAssertEqual(cohort, logic.allocatedCohort)
        } else {
            XCTFail("Unexpected pixel \(String(describing: pixelEvent))", file: file, line: line)
        }

    }

    func assertWhenSecondInteractionWithBookmarksBarOnDayThenNoPixelFired(_ daysAgo: Int) {
        var pixelEvent: Pixel.Event?
        let logic = PixelExperimentLogic {
            pixelEvent = $0
        }
        logic.install()
        _ = logic.cohort
        logic.enrollmentDate = Date.daysAgo(daysAgo)

        logic.fireBookmarksBarInteractionPixel()
        pixelEvent = nil
        logic.fireBookmarksBarInteractionPixel()

        XCTAssertNil(pixelEvent)
    }

}
