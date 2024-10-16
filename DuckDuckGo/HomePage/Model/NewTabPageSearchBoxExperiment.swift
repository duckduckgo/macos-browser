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

final class NewTabPageSearchBoxExperiment {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    enum Cohort: String {
        case control
        case experiment
    }

    enum SearchSource: String {
        case addressBar = "address_bar"
        case ntpAddressBar = "ntp_address_bar"
        case ntpSearchBox = "ntp_search_box"
    }

    var isActive: Bool {
        (daySinceEnrollment() ?? Int.max) <= 7
    }

    var cohort: Cohort? {
        isActive ? userDefaults.experimentCohort : nil
    }

    var onboardingCohort: PixelExperiment? {
        isActive ? PixelExperiment.logic.cohort : nil
    }

    func assignUserToCohort() {
        guard !userDefaults.didRunEnrollment else {
            Logger.newTabPageSearchBoxExperiment.debug("Cohort already assigned, skipping...")
            return
        }

        let cohort: Cohort = Bool.random() ? .experiment : .control
        userDefaults.experimentCohort = cohort
        userDefaults.enrollmentDate = Date()
        userDefaults.didRunEnrollment = true

        Logger.newTabPageSearchBoxExperiment.debug("User assigned to cohort \(cohort.rawValue)")
    }

    func recordSearch(from source: SearchSource) {
        guard let daySinceEnrollment = daySinceEnrollment(), daySinceEnrollment <= 7, let cohort = userDefaults.experimentCohort else {
            return
        }

        var numberOfSearches: Int?

        // if a pixel has ever been fired
        if let daySinceLastPixel = daySinceLastSearchPixel {
            // if a pixel has already been fired today
            if daySinceEnrollment == daySinceLastPixel {
                // only fire if it's been fewer than 10 searches
                if userDefaults.numberOfSearches < 10 {
                    numberOfSearches = userDefaults.numberOfSearches + 1
                } else {
                    Logger.newTabPageSearchBoxExperiment.debug("Maximum number of searches (10) already reported for day \(daySinceEnrollment), skipping pixel.")
                }
            } else {
                // it's the first pixel for a given day
                numberOfSearches = 1
            }
        } else {
            numberOfSearches = 1
        }

        if let numberOfSearches {
            PixelKit.fire(NewTabSearchBoxExperimentPixel.initialSearch(
                day: daySinceEnrollment,
                count: numberOfSearches,
                from: source,
                cohort: cohort,
                onboardingCohort: PixelExperiment.logic.cohort)
            )
            userDefaults.lastPixelTimestamp = Date()
            userDefaults.numberOfSearches = numberOfSearches
        }
    }

    private var daySinceLastSearchPixel: Int? {
        guard let lastPixelTimestamp = userDefaults.lastPixelTimestamp else {
            return nil
        }
        return daySinceEnrollment(until: lastPixelTimestamp)
    }

    private func daySinceEnrollment(until date: Date = Date()) -> Int? {
        guard let enrollmentDate = userDefaults.enrollmentDate else {
            return nil
        }
        let numberOfDays = Calendar.current.dateComponents([.day], from: enrollmentDate, to: date)

        guard let day = numberOfDays.day else {
            return nil
        }
        return day + 1
    }
}

private extension UserDefaults {
    enum Keys {
        static let enrollmentDate = "homepage.searchbox.experiment.enrollment-date"
        static let experimentCohort = "homepage.searchbox.experiment.cohort"
        static let didRunEnrollment = "homepage.searchbox.experiment.did-run-enrollment"
        static let numberOfSearches = "homepage.searchbox.experiment.number-of-searches"
        static let lastPixelTimestamp = "homepage.searchbox.experiment.last-pixel-timestamp"
    }

    var enrollmentDate: Date? {
        get { return object(forKey: Keys.enrollmentDate) as? Date }
        set { set(newValue, forKey: Keys.enrollmentDate) }
    }

    var experimentCohort: NewTabPageSearchBoxExperiment.Cohort? {
        get { return NewTabPageSearchBoxExperiment.Cohort(rawValue: string(forKey: Keys.experimentCohort) ?? "") }
        set { set(newValue?.rawValue, forKey: Keys.experimentCohort) }
    }

    var didRunEnrollment: Bool {
        get { return bool(forKey: Keys.didRunEnrollment) }
        set { set(newValue, forKey: Keys.didRunEnrollment) }
    }

    var numberOfSearches: Int {
        get { return integer(forKey: Keys.numberOfSearches) }
        set { set(newValue, forKey: Keys.numberOfSearches) }
    }

    var lastPixelTimestamp: Date? {
        get { return object(forKey: Keys.lastPixelTimestamp) as? Date }
        set { set(newValue, forKey: Keys.lastPixelTimestamp) }
    }
}
