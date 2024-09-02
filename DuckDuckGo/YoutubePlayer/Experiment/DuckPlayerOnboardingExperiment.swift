//
//  DuckPlayerOnboardingExperiment.swift
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
import PixelKit
import os.log

protocol OnboardingExperimentManager {
    func assignUserToCohort()
    func getPixelParameters(cohort: Bool, date: Bool, experimentName: Bool) -> [String: String]?
}

// https://app.asana.com/0/72649045549333/1208088257884523/f
struct DuckPlayerOnboardingExperiment: OnboardingExperimentManager {
    private let userDefaults: UserDefaults
    private let preferences: DuckPlayerPreferences

    init(userDefault: UserDefaults = .standard,
         preferences: DuckPlayerPreferences = .shared) {
        self.userDefaults = userDefault
        self.preferences = preferences
    }

    enum Cohort: String {
        case control
        case experiment
    }

    private enum ExperimentPixelValues {
        static let name = "priming-modal"
    }

    private var enrollmentDate: Date?

    func assignUserToCohort() {
        guard !userDefaults.didRunEnrollment else {
            Logger.duckPlayerOnboardingExperiment.debug("Cohort already assigned, skipping...")
            return
        }

        let cohort: Cohort = Bool.random() ? .experiment : .control
        userDefaults.experimentCohort = cohort
        userDefaults.enrollmentDate = Date()
        userDefaults.didRunEnrollment = true

        PixelKit.fire(NonStandardEvent(DuckPlayerOnboardingExperimentPixel.enrollmentPixel))
        Logger.duckPlayerOnboardingExperiment.debug("User assigned to cohort \(cohort.rawValue)")
    }

    func sendWeeklyUniqueView() {
        // m_mac_duck-player_weekly-unique-view
    }
    /*
     Duck Player DAUs
     YouTube overlay CTR
     SERP overlay CTR
     Users changing settings to Never
     Users changing settings to Always
     */
    func getPixelParameters(cohort: Bool = true,
                            date: Bool = true,
                            experimentName: Bool = true) -> [String: String]? {
        var parameters: [String: String] = [:]

        if let experimentCohort = experimentCohort, cohort {
            parameters["variant"] = experimentCohort.rawValue
        }

        if let enrollmentDate = enrollmentDate, date {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            let enrollmentDateString = dateFormatter.string(from: enrollmentDate)
            parameters["enrollment"] = enrollmentDateString
        }

        if experimentName {
            parameters["expname"] = ExperimentPixelValues.name
        }

        return parameters.isEmpty ? nil : parameters
    }

    private var isUserInExperiment: Bool {
        return enrollmentDate != nil
    }

    private var experimentCohort: Cohort? {
        return userDefaults.experimentCohort
    }

    func reset() {
        userDefaults.enrollmentDate = nil
        userDefaults.experimentCohort = nil
        userDefaults.didRunEnrollment = false

    }
}

private extension UserDefaults {
    enum Keys {
        static let enrollmentDate = "duckplayer.onboarding.experiment-enrollment-date"
        static let experimentCohort = "duckplayer.onboarding.experiment-cohort"
        static let didRunEnrollment = "duckplayer.onboarding.experiment-did-run-enrollment"

    }

    var enrollmentDate: Date? {
        get { return object(forKey: Keys.enrollmentDate) as? Date }
        set { set(newValue, forKey: Keys.enrollmentDate) }
    }

    var experimentCohort: DuckPlayerOnboardingExperiment.Cohort? {
        get { return DuckPlayerOnboardingExperiment.Cohort(rawValue: string(forKey: Keys.experimentCohort) ?? "") }
        set { set(newValue?.rawValue, forKey: Keys.experimentCohort) }
    }

    var didRunEnrollment: Bool {
        get { return bool(forKey: Keys.didRunEnrollment) }
        set { set(newValue, forKey: Keys.didRunEnrollment) }
    }
}
