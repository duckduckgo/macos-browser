//
//  NewTabPageSearchBoxExperimentTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Common
import XCTest
@testable import DuckDuckGo_Privacy_Browser

class MockNewTabPageSearchBoxExperimentCohortDecider: NewTabPageSearchBoxExperimentCohortDeciding {
    var cohort: NewTabPageSearchBoxExperiment.Cohort?
}

class MockOnboardingExperimentCohortProvider: OnboardingExperimentCohortProviding {
    var isOnboardingFinished: Bool = true
    var onboardingExperimentCohort: PixelExperiment?
}

class CapturingNewTabPageSearchBoxExperimentPixelReporter: NewTabPageSearchBoxExperimentPixelReporting {
    struct PixelArguments: Equatable {
        var day: Int
        var count: Int
        var from: NewTabPageSearchBoxExperiment.SearchSource
        var cohort: NewTabPageSearchBoxExperiment.Cohort
        var onboardingCohort: PixelExperiment?
    }
    var calls: [PixelArguments] = []

    var cohortAssignmentCalls: [NewTabPageSearchBoxExperiment.Cohort] = []

    func fireNTPSearchBoxExperimentCohortAssignmentPixel(cohort: NewTabPageSearchBoxExperiment.Cohort, onboardingCohort: PixelExperiment?) {
        cohortAssignmentCalls.append(cohort)
    }

    func fireNTPSearchBoxExperimentPixel(
        day: Int,
        count: Int,
        from: NewTabPageSearchBoxExperiment.SearchSource,
        cohort: NewTabPageSearchBoxExperiment.Cohort,
        onboardingCohort: PixelExperiment?
    ) {
        calls.append(.init(day: day, count: count, from: from, cohort: cohort, onboardingCohort: onboardingCohort))
    }
}

final class NewTabPageSearchBoxExperimentTests: XCTestCase {
    var experiment: NewTabPageSearchBoxExperiment!
    var suiteName: String!
    var userDefaults: UserDefaults!
    var dataStore: DefaultNewTabPageSearchBoxExperimentDataStore!
    var cohortDecider: MockNewTabPageSearchBoxExperimentCohortDecider!
    var onboardingExperimentCohortProvider: MockOnboardingExperimentCohortProvider!
    var pixelReporter: CapturingNewTabPageSearchBoxExperimentPixelReporter!

    override func setUp() {
        super.setUp()

        suiteName = UUID().uuidString
        userDefaults = UserDefaults(suiteName: suiteName)
        dataStore = DefaultNewTabPageSearchBoxExperimentDataStore(userDefaults: userDefaults)
        cohortDecider = MockNewTabPageSearchBoxExperimentCohortDecider()
        onboardingExperimentCohortProvider = MockOnboardingExperimentCohortProvider()
        pixelReporter = CapturingNewTabPageSearchBoxExperimentPixelReporter()

        experiment = NewTabPageSearchBoxExperiment(
            dataStore: DefaultNewTabPageSearchBoxExperimentDataStore(userDefaults: userDefaults),
            cohortDecider: cohortDecider,
            onboardingExperimentCohortProvider: onboardingExperimentCohortProvider,
            pixelReporter: pixelReporter
        )
    }

    override func tearDown() {
        userDefaults.removeSuite(named: suiteName)
        super.tearDown()
    }

    func testThatLegacyAndCurrentExperimentCohortsAreCorrectlyIdentified() {
        XCTAssertTrue(NewTabPageSearchBoxExperiment.Cohort.experiment.isExperiment)
        XCTAssertTrue(NewTabPageSearchBoxExperiment.Cohort.experimentExistingUser.isExperiment)
        XCTAssertTrue(NewTabPageSearchBoxExperiment.Cohort.legacyExperiment.isExperiment)
        XCTAssertTrue(NewTabPageSearchBoxExperiment.Cohort.legacyExperimentExistingUser.isExperiment)

        XCTAssertFalse(NewTabPageSearchBoxExperiment.Cohort.control.isExperiment)
        XCTAssertFalse(NewTabPageSearchBoxExperiment.Cohort.controlExistingUser.isExperiment)
        XCTAssertFalse(NewTabPageSearchBoxExperiment.Cohort.legacyControl.isExperiment)
        XCTAssertFalse(NewTabPageSearchBoxExperiment.Cohort.legacyControlExistingUser.isExperiment)
    }

    func testWhenUserIsNotEnrolledAndOnboardingIsNotFinishedThenCohortIsNotSet() {
        onboardingExperimentCohortProvider.isOnboardingFinished = false
        cohortDecider.cohort = .experimentExistingUser
        let date = Date()
        experiment.assignUserToCohort()

        XCTAssertFalse(dataStore.didRunEnrollment)
        XCTAssertFalse(experiment.isActive)
        XCTAssertNil(dataStore.enrollmentDate)
        XCTAssertNil(experiment.cohort)
        XCTAssertTrue(pixelReporter.cohortAssignmentCalls.isEmpty)
    }

    func testWhenUserIsNotEnrolledAndIsEligibleForExperimentThenCohortIsSet() throws {
        cohortDecider.cohort = .experimentExistingUser
        let date = Date()
        experiment.assignUserToCohort()

        XCTAssertTrue(dataStore.didRunEnrollment)
        XCTAssertTrue(experiment.isActive)
        XCTAssertGreaterThan(try XCTUnwrap(dataStore.enrollmentDate), date)
        XCTAssertEqual(experiment.cohort, cohortDecider.cohort)
        XCTAssertEqual(pixelReporter.cohortAssignmentCalls, [cohortDecider.cohort])
    }

    func testWhenUserIsNotEnrolledAndIsNotEligibleForExperimentThenCohortIsNil() {
        dataStore.didRunEnrollment = false
        dataStore.experimentCohort = .control

        experiment.assignUserToCohort()

        XCTAssertTrue(dataStore.didRunEnrollment)
        XCTAssertFalse(experiment.isActive)
        XCTAssertNil(experiment.cohort)
        XCTAssertTrue(pixelReporter.cohortAssignmentCalls.isEmpty)
    }

    func testWhenUserIsEnrolledThenSubsequentCohortAssignmentsHaveNoEffect() {
        dataStore.didRunEnrollment = true
        dataStore.experimentCohort = .control
        let date = Date()
        dataStore.enrollmentDate = date

        experiment.assignUserToCohort()

        XCTAssertTrue(dataStore.didRunEnrollment)
        XCTAssertEqual(experiment.cohort, .control)
        XCTAssertEqual(dataStore.enrollmentDate, date)
        XCTAssertTrue(pixelReporter.cohortAssignmentCalls.isEmpty)
    }

    func testWhenUserIsEnrolledThenIsActiveReturnsFalseWhenExperimentExpires() {
        dataStore.didRunEnrollment = true
        dataStore.experimentCohort = .experiment
        dataStore.enrollmentDate = Date.daysAgo(NewTabPageSearchBoxExperiment.Const.experimentDurationInDays - 1)

        XCTAssertTrue(experiment.isActive)

        dataStore.enrollmentDate = Date.daysAgo(NewTabPageSearchBoxExperiment.Const.experimentDurationInDays)
        XCTAssertFalse(experiment.isActive)
    }

    func testWhenExperimentIsInactiveThenCohortStays() {
        dataStore.didRunEnrollment = true
        dataStore.experimentCohort = .experiment
        dataStore.enrollmentDate = Date.daysAgo(NewTabPageSearchBoxExperiment.Const.experimentDurationInDays)

        XCTAssertEqual(experiment.cohort, .experiment)
    }

    func testWhenExperimentIsInactiveThenOnboardingExperimentCohortIsNil() {
        dataStore.didRunEnrollment = true
        dataStore.experimentCohort = .experiment
        onboardingExperimentCohortProvider.onboardingExperimentCohort = .newOnboarding
        dataStore.enrollmentDate = Date.daysAgo(NewTabPageSearchBoxExperiment.Const.experimentDurationInDays)

        XCTAssertNil(experiment.onboardingCohort)
    }

    func testThatRecordSearchRecordsMaximum10SearchesPerDay() {
        onboardingExperimentCohortProvider.onboardingExperimentCohort = .newOnboarding
        dataStore.didRunEnrollment = true
        dataStore.experimentCohort = .control
        dataStore.enrollmentDate = Date()

        (0..<20).forEach { _ in
            experiment.recordSearch(from: .addressBar)
        }

        dataStore.enrollmentDate = Date.daysAgo(1)
        experiment.recordSearch(from: .ntpSearchBox)

        XCTAssertEqual(pixelReporter.calls.count, 11)
        XCTAssertEqual(
            pixelReporter.calls,
            [
                CapturingNewTabPageSearchBoxExperimentPixelReporter
                    .PixelArguments(day: 1, count: 1, from: .addressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 1, count: 2, from: .addressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 1, count: 3, from: .addressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 1, count: 4, from: .addressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 1, count: 5, from: .addressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 1, count: 6, from: .addressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 1, count: 7, from: .addressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 1, count: 8, from: .addressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 1, count: 9, from: .addressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 1, count: 10, from: .addressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 2, count: 1, from: .ntpSearchBox, cohort: .control, onboardingCohort: .newOnboarding)
            ]
        )
    }

    func testThatRecordSearchResetsCountOnNextDayIfMaximumSearchesPerDayWasNotReached() {
        onboardingExperimentCohortProvider.onboardingExperimentCohort = .newOnboarding
        dataStore.didRunEnrollment = true
        dataStore.experimentCohort = .control
        dataStore.enrollmentDate = Date()

        experiment.recordSearch(from: .addressBar)
        experiment.recordSearch(from: .ntpAddressBar)

        dataStore.enrollmentDate = Date.daysAgo(1)
        experiment.recordSearch(from: .ntpSearchBox)

        dataStore.enrollmentDate = Date.daysAgo(2)
        experiment.recordSearch(from: .ntpSearchBox)
        experiment.recordSearch(from: .ntpSearchBox)
        experiment.recordSearch(from: .ntpSearchBox)

        dataStore.enrollmentDate = Date.daysAgo(3)
        experiment.recordSearch(from: .ntpAddressBar)
        experiment.recordSearch(from: .ntpSearchBox)

        dataStore.enrollmentDate = Date.daysAgo(5)
        experiment.recordSearch(from: .ntpSearchBox)
        experiment.recordSearch(from: .addressBar)
        experiment.recordSearch(from: .ntpAddressBar)

        XCTAssertEqual(pixelReporter.calls.count, 11)
        XCTAssertEqual(
            pixelReporter.calls,
            [
                CapturingNewTabPageSearchBoxExperimentPixelReporter
                    .PixelArguments(day: 1, count: 1, from: .addressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 1, count: 2, from: .ntpAddressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 2, count: 1, from: .ntpSearchBox, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 3, count: 1, from: .ntpSearchBox, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 3, count: 2, from: .ntpSearchBox, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 3, count: 3, from: .ntpSearchBox, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 4, count: 1, from: .ntpAddressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 4, count: 2, from: .ntpSearchBox, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 6, count: 1, from: .ntpSearchBox, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 6, count: 2, from: .addressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 6, count: 3, from: .ntpAddressBar, cohort: .control, onboardingCohort: .newOnboarding)
            ]
        )
    }

    func testThatRecordSearchStopsReportingPixelsAfterExperimentHasExpired() {
        onboardingExperimentCohortProvider.onboardingExperimentCohort = .newOnboarding
        dataStore.didRunEnrollment = true
        dataStore.experimentCohort = .control
        dataStore.enrollmentDate = Date.daysAgo(4)

        experiment.recordSearch(from: .addressBar)
        experiment.recordSearch(from: .ntpAddressBar)

        dataStore.enrollmentDate = Date.daysAgo(10)
        experiment.recordSearch(from: .ntpSearchBox)

        XCTAssertEqual(pixelReporter.calls.count, 2)
        XCTAssertEqual(
            pixelReporter.calls,
            [
                CapturingNewTabPageSearchBoxExperimentPixelReporter
                    .PixelArguments(day: 5, count: 1, from: .addressBar, cohort: .control, onboardingCohort: .newOnboarding),
                .init(day: 5, count: 2, from: .ntpAddressBar, cohort: .control, onboardingCohort: .newOnboarding)
            ]
        )
    }
}
