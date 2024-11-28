//
//  NewTabPageSearchBoxExperiment.swift
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

import Foundation
import os.log
import PixelKit

protocol NewTabPageSearchBoxExperimentDataStoring: AnyObject {
    var enrollmentDate: Date? { get set }
    var experimentCohort: NewTabPageSearchBoxExperiment.Cohort? { get set }
    var didRunEnrollment: Bool { get set }
    var numberOfSearches: Int { get set }
    var lastPixelTimestamp: Date? { get set }
}

final class DefaultNewTabPageSearchBoxExperimentDataStore: NewTabPageSearchBoxExperimentDataStoring {
    enum Keys {
        static let enrollmentDate = "homepage.searchbox.experiment.enrollment-date"
        static let experimentCohort = "homepage.searchbox.experiment.cohort"
        static let didRunEnrollment = "homepage.searchbox.experiment.did-run-enrollment"
        static let numberOfSearches = "homepage.searchbox.experiment.number-of-searches"
        static let lastPixelTimestamp = "homepage.searchbox.experiment.last-pixel-timestamp"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var enrollmentDate: Date? {
        get { return userDefaults.object(forKey: Keys.enrollmentDate) as? Date }
        set { userDefaults.set(newValue, forKey: Keys.enrollmentDate) }
    }

    var experimentCohort: NewTabPageSearchBoxExperiment.Cohort? {
        get { return NewTabPageSearchBoxExperiment.Cohort(rawValue: userDefaults.string(forKey: Keys.experimentCohort) ?? "") }
        set { userDefaults.set(newValue?.rawValue, forKey: Keys.experimentCohort) }
    }

    var didRunEnrollment: Bool {
        get { return userDefaults.bool(forKey: Keys.didRunEnrollment) }
        set { userDefaults.set(newValue, forKey: Keys.didRunEnrollment) }
    }

    var numberOfSearches: Int {
        get { return userDefaults.integer(forKey: Keys.numberOfSearches) }
        set { userDefaults.set(newValue, forKey: Keys.numberOfSearches) }
    }

    var lastPixelTimestamp: Date? {
        get { return userDefaults.object(forKey: Keys.lastPixelTimestamp) as? Date }
        set { userDefaults.set(newValue, forKey: Keys.lastPixelTimestamp) }
    }
}

protocol NewTabPageSearchBoxExperimentCohortDeciding {
    var cohort: NewTabPageSearchBoxExperiment.Cohort? { get }
}

struct DefaultNewTabPageSearchBoxExperimentCohortDecider: NewTabPageSearchBoxExperimentCohortDeciding {
    var cohort: NewTabPageSearchBoxExperiment.Cohort? {
        if NSApp.runType == .uiTests {
            return nil
        }

        // We enroll all new users
        if AppDelegate.isNewUser {
            return Bool.random() ? .experiment : .control
        }

        // We also enroll some users that have used the app for more than 1 month
        guard AppDelegate.firstLaunchDate < Date.monthAgo else {
            return nil
        }

        // 5% control group and 5% experiment
        switch Int.random(in: 0..<100) {
        case 0..<5: return .experimentExistingUser
        case 5..<10: return .controlExistingUser
        default: return nil
        }
    }
}

protocol NewTabPageSearchBoxExperimentPixelReporting {
    func fireNTPSearchBoxExperimentCohortAssignmentPixel(
        cohort: NewTabPageSearchBoxExperiment.Cohort,
        onboardingCohort: PixelExperiment?
    )

    func fireNTPSearchBoxExperimentPixel(
        day: Int,
        count: Int,
        from: NewTabPageSearchBoxExperiment.SearchSource,
        cohort: NewTabPageSearchBoxExperiment.Cohort,
        onboardingCohort: PixelExperiment?
    )
}

struct DefaultNewTabPageSearchBoxExperimentPixelReporter: NewTabPageSearchBoxExperimentPixelReporting {

    func fireNTPSearchBoxExperimentCohortAssignmentPixel(cohort: NewTabPageSearchBoxExperiment.Cohort, onboardingCohort: PixelExperiment?) {
        PixelKit.fire(NewTabSearchBoxExperimentPixel.cohortAssigned(cohort: cohort, onboardingCohort: onboardingCohort))
    }

    func fireNTPSearchBoxExperimentPixel(
        day: Int,
        count: Int,
        from: NewTabPageSearchBoxExperiment.SearchSource,
        cohort: NewTabPageSearchBoxExperiment.Cohort,
        onboardingCohort: PixelExperiment?
    ) {
        PixelKit.fire(
            NewTabSearchBoxExperimentPixel.initialSearch(
                day: day,
                count: count,
                from: from,
                cohort: cohort,
                onboardingCohort: onboardingCohort
            )
        )
    }
}

protocol OnboardingExperimentCohortProviding {
    var isOnboardingFinished: Bool { get }
    var onboardingExperimentCohort: PixelExperiment? { get }
}

struct DefaultOnboardingExperimentCohortProvider: OnboardingExperimentCohortProviding {
    var isOnboardingFinished: Bool {
        UserDefaultsWrapper<Bool>(key: .onboardingFinished, defaultValue: false).wrappedValue
    }

    var onboardingExperimentCohort: PixelExperiment? {
        PixelExperiment.logic.cohort
    }
}

final class NewTabPageSearchBoxExperiment {

    private let dataStore: NewTabPageSearchBoxExperimentDataStoring
    private let cohortDecider: NewTabPageSearchBoxExperimentCohortDeciding
    private let onboardingExperimentCohortProvider: OnboardingExperimentCohortProviding
    private let pixelReporter: NewTabPageSearchBoxExperimentPixelReporting

    init(
        dataStore: NewTabPageSearchBoxExperimentDataStoring = DefaultNewTabPageSearchBoxExperimentDataStore(),
        cohortDecider: NewTabPageSearchBoxExperimentCohortDeciding = DefaultNewTabPageSearchBoxExperimentCohortDecider(),
        onboardingExperimentCohortProvider: OnboardingExperimentCohortProviding = DefaultOnboardingExperimentCohortProvider(),
        pixelReporter: NewTabPageSearchBoxExperimentPixelReporting = DefaultNewTabPageSearchBoxExperimentPixelReporter()
    ) {
        self.dataStore = dataStore
        self.cohortDecider = cohortDecider
        self.onboardingExperimentCohortProvider = onboardingExperimentCohortProvider
        self.pixelReporter = pixelReporter
    }

    enum Cohort: String {
        case control = "control_v2"
        case experiment = "ntp_search_box_v2"
        case controlExistingUser = "control_existing_user_v2"
        case experimentExistingUser = "ntp_search_box_existing_user_v2"
        case legacyControl = "control"
        case legacyExperiment = "ntp_search_box"
        case legacyControlExistingUser = "control_existing_user"
        case legacyExperimentExistingUser = "ntp_search_box_existing_user"

        static let allExperimentCohortValues: Set<Cohort> = [
            .legacyExperiment,
            .legacyExperimentExistingUser,
            .experiment,
            .experimentExistingUser
        ]

        var isExperiment: Bool {
            return Self.allExperimentCohortValues.contains(self)
        }
    }

    enum SearchSource: String {
        case addressBar = "address_bar"
        case ntpAddressBar = "ntp_address_bar"
        case ntpSearchBox = "ntp_search_box"
    }

    enum Const {
        static let experimentDurationInDays: Int = 7
        static let maxNumberOfSearchesPerDay: Int = 10
    }

    var isActive: Bool {
        (daySinceEnrollment() ?? Int.max) <= Const.experimentDurationInDays
    }

    var cohort: Cohort? {
        dataStore.experimentCohort
    }

    var onboardingCohort: PixelExperiment? {
        isActive ? onboardingExperimentCohortProvider.onboardingExperimentCohort : nil
    }

    func assignUserToCohort() {
        guard !dataStore.didRunEnrollment else {
            Logger.newTabPageSearchBoxExperiment.debug("Cohort already assigned, skipping...")
            return
        }

        guard onboardingExperimentCohortProvider.isOnboardingFinished else {
            Logger.newTabPageSearchBoxExperiment.debug("Skipping cohort assignment until onboarding is finished...")
            return
        }

        guard let cohort = cohortDecider.cohort else {
            Logger.newTabPageSearchBoxExperiment.debug("User is not eligible for the experiment, skipping cohort assignment...")
            dataStore.experimentCohort = nil
            dataStore.didRunEnrollment = true
            return
        }

        dataStore.experimentCohort = cohort
        dataStore.enrollmentDate = Date()
        dataStore.didRunEnrollment = true

        Logger.newTabPageSearchBoxExperiment.debug("User assigned to cohort \(cohort.rawValue)")
        pixelReporter.fireNTPSearchBoxExperimentCohortAssignmentPixel(cohort: cohort, onboardingCohort: onboardingExperimentCohortProvider.onboardingExperimentCohort)
    }

    func recordSearch(from source: SearchSource) {
        guard isActive, let daySinceEnrollment = daySinceEnrollment(), let cohort = dataStore.experimentCohort else {
            return
        }

        var numberOfSearches: Int?

        // if a pixel has ever been fired
        if let daySinceEnrollmentForLastSearchPixelTimestamp {
            // if a pixel has already been fired today
            if daySinceEnrollmentForLastSearchPixelTimestamp == daySinceEnrollment {
                // only fire if it's been fewer than 10 searches
                if dataStore.numberOfSearches < Const.maxNumberOfSearchesPerDay {
                    numberOfSearches = dataStore.numberOfSearches + 1
                } else {
                    Logger.newTabPageSearchBoxExperiment.debug("Maximum number of searches (\(Const.maxNumberOfSearchesPerDay)) already reported for day \(daySinceEnrollment), skipping pixel.")
                }
            } else {
                // it's the first pixel for a given day
                numberOfSearches = 1
            }
        } else {
            numberOfSearches = 1
        }

        if let numberOfSearches {
            pixelReporter.fireNTPSearchBoxExperimentPixel(
                day: daySinceEnrollment,
                count: numberOfSearches,
                from: source,
                cohort: cohort,
                onboardingCohort: onboardingExperimentCohortProvider.onboardingExperimentCohort
            )
            dataStore.lastPixelTimestamp = Date()
            dataStore.numberOfSearches = numberOfSearches
        }
    }

    private var daySinceEnrollmentForLastSearchPixelTimestamp: Int? {
        guard let lastPixelTimestamp = dataStore.lastPixelTimestamp else {
            return nil
        }
        return daySinceEnrollment(until: lastPixelTimestamp)
    }

    private func daySinceEnrollment(until date: Date = Date()) -> Int? {
        guard let enrollmentDate = dataStore.enrollmentDate else {
            return nil
        }
        let numberOfDays = Calendar.current.dateComponents([.day], from: enrollmentDate, to: date)

        guard let day = numberOfDays.day else {
            return nil
        }
        return day + 1
    }
}
