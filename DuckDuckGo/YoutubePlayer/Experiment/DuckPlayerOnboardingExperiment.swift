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

protocol OnboardingExperimentManager {
    func assignUserToCohort()
    func sendEnrollmentPixel()
    func getPixelParameters() -> [String: String]?
}

// https://app.asana.com/0/72649045549333/1208088257884523/f
struct DuckPlayerOnboardingExperiment: OnboardingExperimentManager {
    private let userDefaults: UserDefaults
    private let preferences: DuckPlayerPreferences

    enum Cohort: String {
        case control
        case experiment
    }

    private enum ExperimentPixelValues {
        static let name = "priming-modal"
    }

    private var enrollmentDate: Date?

    func assignUserToCohort() {
        let cohort: Cohort = Bool.random() ? .experiment : .control
        userDefaults.experimentCohort = cohort
        userDefaults.enrollmentDate = Date()
    }

    func sendEnrollmentPixel() {
        // to do
        // duckplayer_experiment_cohort_assign
        /*
         Sent when a user enrolls in the experiment
         variant (Variant) = control | experiment
         expname (experimnet name) = priming-modal
         */
    }

    func getPixelParameters() -> [String: String]? {
        guard isUserInExperiment,
              let experimentCohort = experimentCohort,
              let enrollmentDate = enrollmentDate,
              let enrollmentDateComponents = Calendar.current.dateComponents([.month, .day], from: enrollmentDate),
              let month = enrollmentDateComponents.month,
              let day = enrollmentDateComponents.day else { return nil }

        let enrollmentDateString = String(format: "%02d%02d", month, day)

        return [
            "enrollment": enrollmentDateString,
            "variant": experimentCohort.rawValue
        ]
    }

    private var isUserInExperiment: Bool {
        return enrollmentDate != nil
    }

    private var experimentCohort: Cohort? {
        return userDefaults.experimentCohort
    }
}

private extension UserDefaults {
    enum Keys {
        static let enrollmentDate = "onboarding.experiment-enrollment-date"
        static let experimentCohort = "onboarding.experiment-cohort"
    }

    var enrollmentDate: Date? {
        get { return object(forKey: Keys.enrollmentDate) as? Date }
        set { set(newValue, forKey: Keys.enrollmentDate) }
    }

    var experimentCohort: DuckPlayerOnboardingExperiment.Cohort? {
        get { return DuckPlayerOnboardingExperiment.Cohort(rawValue: string(forKey: Keys.experimentCohort) ?? "") }
        set { set(newValue?.rawValue, forKey: Keys.experimentCohort) }
    }
}
