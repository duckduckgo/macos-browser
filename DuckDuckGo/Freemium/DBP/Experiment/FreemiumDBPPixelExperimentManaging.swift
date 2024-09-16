//
//  FreemiumDBPPixelExperimentManaging.swift
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
import Subscription
import OSLog

/// Protocol defining the interface for managing Freemium DBP pixel experiments.
protocol FreemiumDBPPixelExperimentManaging {
    
    /// Property indicating if the user is in the treatment cohort or not
    var isTreatment: Bool { get }

    /// Parameters to be sent with pixel events, representing the user's experiment cohort and enrollment date.
    var pixelParameters: [String: String]? { get }

    /// Assigns the user to an experimental cohort if eligible.
    func assignUserToCohort()
}

/// Manager responsible for handling user assignments to experimental cohorts and providing pixel parameters for analytics.
final class FreemiumDBPPixelExperimentManager: FreemiumDBPPixelExperimentManaging {

    /// Represents the different experimental cohorts a user can be assigned to.
    enum Cohort: String {
        case control
        case treatment
    }

    /// Keys used for storing experiment-related data in `UserDefaults`.
    private enum PixelKeys {
        static let variant = "variant"
        static let enrollment = "enrollment"
    }

    // MARK: - Dependencies

    private let subscriptionManager: SubscriptionManager
    private let userDefaults: UserDefaults
    private let locale: Locale

    // MARK: - Initialization

    /// Initializes the experiment manager with necessary dependencies.
    ///
    /// - Parameters:
    ///   - subscriptionManager: Manages user subscriptions.
    ///   - userDefaults: Storage for experiment data. Defaults to `.dbp`.
    ///   - locale: Determines user eligibility based on region. Defaults to `Locale.current`.
    init(subscriptionManager: SubscriptionManager,
         userDefaults: UserDefaults = .dbp,
         locale: Locale = Locale.current) {
        self.subscriptionManager = subscriptionManager
        self.userDefaults = userDefaults
        self.locale = locale
    }

    // MARK: - FreemiumDBPPixelExperimentManaging

    var isTreatment: Bool {
        experimentCohort == .treatment
    }

    var pixelParameters: [String: String]? {
        var parameters: [String: String] = [:]

        if let experimentCohort = experimentCohort {
            parameters[PixelKeys.variant] = experimentCohort.rawValue
        }

        if let enrollmentDate = enrollmentDate {
            let dateString = DateFormatter.yearMonthDay(from: enrollmentDate)
            parameters[PixelKeys.enrollment] = dateString
        }

        return parameters.isEmpty ? nil : parameters
    }

    /// Assigns the user to a cohort (`control` or `treatment`) if eligible and not already enrolled.
    func assignUserToCohort() {
        guard shouldEnroll else { return }

        let cohort: Cohort = Bool.random() ? .control : .treatment
        userDefaults.experimentCohort = cohort
        userDefaults.enrollmentDate = Date()

        // TODO: Fire enrollment pixel
        Logger.freemiumDBP.debug("[Freemium DBP] User enrolled to cohort: \(cohort.rawValue)")
    }
}

// MARK: - Private Extensions

private extension FreemiumDBPPixelExperimentManager {

    /// Determines if the user is eligible for the experiment based on subscription status and locale.
    var userIsEligible: Bool {
        subscriptionManager.isPotentialPrivacyProSubscriber
        && locale.isUSRegion
    }

    /// Checks if the user is not already enrolled in the experiment.
    var userIsNotEnrolled: Bool {
        userDefaults.enrollmentDate == nil
    }

    /// Determines whether the user should be enrolled in the experiment.
    var shouldEnroll: Bool {
        guard userIsNotEnrolled else {
            Logger.freemiumDBP.debug("[Freemium DBP] User is already enrolled in experiment")
            return false
        }

        guard userIsEligible else {
            Logger.freemiumDBP.debug("[Freemium DBP] User is ineligible for experiment")
            return false
        }

        return true
    }

    /// Retrieves the user's enrollment date from `UserDefaults`.
    var enrollmentDate: Date? {
        userDefaults.enrollmentDate
    }

    /// Retrieves the user's assigned experiment cohort from `UserDefaults`.
    var experimentCohort: Cohort? {
        userDefaults.experimentCohort
    }
}

private extension Locale {

    /// Determines if the locale's region is the United States.
    var isUSRegion: Bool {
        var regionCode = self.regionCode

        if #available(macOS 13, *) {
            regionCode = self.region?.identifier ?? self.regionCode
        }

        return regionCode == "US"
    }
}

private extension DateFormatter {

    /// Formats a date into a string with "yyyyMMdd" format.
    ///
    /// - Parameter date: The date to format.
    /// - Returns: A string representing the date in "yyyyMMdd" format.
    static func yearMonthDay(from date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter.string(from: date)
    }
}

private extension UserDefaults {

    /// Keys used for storing experiment-related data.
    enum Keys {
        static let enrollmentDate = "freemium.dbp.experiment.enrollment-date"
        static let experimentCohort = "freemium.dbp.experiment.cohort"
    }

    /// Stores or retrieves the user's enrollment date for the experiment.
    var enrollmentDate: Date? {
        get { return object(forKey: Keys.enrollmentDate) as? Date }
        set { set(newValue, forKey: Keys.enrollmentDate) }
    }

    /// Stores or retrieves the user's assigned experiment cohort.
    var experimentCohort: FreemiumDBPPixelExperimentManager.Cohort? {
        get { FreemiumDBPPixelExperimentManager.Cohort(rawValue: string(forKey: Keys.experimentCohort) ?? "") }
        set { set(newValue?.rawValue, forKey: Keys.experimentCohort) }
    }
}
