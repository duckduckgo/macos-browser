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
    /// Assigns the user to a cohort for the onboarding experiment.
    func assignUserToCohort()

    /// Retrieves pixel parameters for tracking the experiment.
    /// - Parameters:
    ///   - cohort: A Boolean indicating whether to include the cohort information.
    ///   - date: A Boolean indicating whether to include the enrollment date.
    ///   - experimentName: A Boolean indicating whether to include the experiment name.
    /// - Returns: A dictionary containing pixel parameters, or nil if no parameters are available.
    func getPixelParameters(cohort: Bool, date: Bool, experimentName: Bool) -> [String: String]?

    /// Fires a pixel for tracking unique views on a weekly basis.
    /// - Parameter extraParams: Additional parameters to include with the pixel event.
    func fireWeeklyUniqueViewPixel(extraParams: [String: String]?)

    /// A Boolean value indicating whether the user is assigned to the experiment cohort.
    var isUserAssignedToExperimentCohort: Bool { get }
}

// https://app.asana.com/0/72649045549333/1208088257884523/f
struct DuckPlayerOnboardingExperiment: OnboardingExperimentManager {
    private let userDefaults: UserDefaults

    init(userDefault: UserDefaults = .standard) {
        self.userDefaults = userDefault
    }

    enum Cohort: String {
        case control
        case experiment
    }

    private enum ExperimentPixelValues {
        static let name = "priming-modal"
    }

    private enum ExperimentPixelKeys {
        static let variant = "variant"
        static let enrollment = "enrollment"
        static let experimentName = "expname"
        static let onboardingCohort = "onboarding-cohort"
    }

    var isUserAssignedToExperimentCohort: Bool {
        guard enrollmentDate != nil else { return false }
        return experimentCohort == .experiment
    }

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

    func fireWeeklyUniqueViewPixel(extraParams: [String: String]?) {
        guard enrollmentDate != nil else { return }

        if shouldFireWeeklyPixel() {
            PixelKit.fire(NonStandardEvent(DuckPlayerOnboardingExperimentPixel.weeklyUniqueView),
                          withAdditionalParameters: extraParams)
            userDefaults.weeklyPixelSentDate = Date()
        }
    }

    func getPixelParameters(cohort: Bool = true,
                            date: Bool = true,
                            experimentName: Bool = true) -> [String: String]? {
        var parameters: [String: String] = [:]

        if let experimentCohort = experimentCohort, cohort {
            parameters[ExperimentPixelKeys.variant] = experimentCohort.rawValue
        }

        if let enrollmentDate = enrollmentDate, date {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            let enrollmentDateString = dateFormatter.string(from: enrollmentDate)
            parameters[ExperimentPixelKeys.enrollment] = enrollmentDateString
        }

        if experimentName {
            parameters[ExperimentPixelKeys.experimentName] = ExperimentPixelValues.name
        }

        if PixelExperiment.isExperimentInstalled,
           let onboardingExperimentCohort = PixelExperiment.logic.allocatedCohort {
            parameters[ExperimentPixelKeys.onboardingCohort] = onboardingExperimentCohort
        }

        return parameters.isEmpty ? nil : parameters
    }

    private var enrollmentDate: Date? {
        return userDefaults.enrollmentDate
    }

    private var experimentCohort: Cohort? {
        return userDefaults.experimentCohort
    }

    func reset() {
        userDefaults.enrollmentDate = nil
        userDefaults.experimentCohort = nil
        userDefaults.didRunEnrollment = false
        userDefaults.weeklyPixelSentDate = nil
    }

    private func shouldFireWeeklyPixel() -> Bool {
        guard let lastFiredDate = userDefaults.weeklyPixelSentDate else { return true }
        return DataBrokerProtectionPixelsUtilities.shouldFirePixel(startDate: lastFiredDate,
                                                                   endDate: Date(),
                                                                   daysDifference: .weekly)
    }
}

private extension UserDefaults {
    enum Keys {
        static let enrollmentDate = "duckplayer.onboarding.experiment-enrollment-date"
        static let experimentCohort = "duckplayer.onboarding.experiment-cohort"
        static let didRunEnrollment = "duckplayer.onboarding.experiment-did-run-enrollment"
        static let weeklyPixelSentDate = "duckplayer.onboarding.experiment-weekly-pixel-sent-date"
    }

    var enrollmentDate: Date? {
        get { return object(forKey: Keys.enrollmentDate) as? Date }
        set { set(newValue, forKey: Keys.enrollmentDate) }
    }

    var weeklyPixelSentDate: Date? {
        get { return object(forKey: Keys.weeklyPixelSentDate) as? Date }
        set { set(newValue, forKey: Keys.weeklyPixelSentDate) }
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
