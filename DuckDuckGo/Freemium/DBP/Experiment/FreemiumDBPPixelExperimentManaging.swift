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
import PixelKit

/// Protocol defining the interface for managing Freemium DBP pixel experiments.
protocol FreemiumDBPPixelExperimentManaging {

    /// Property indicating if the user is in the treatment cohort or not
    var isTreatment: Bool { get }

    /// Property which provides parameters for experiment pixels
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

    private enum PixelKeys {
        static let daysEnrolled = "daysEnrolled"
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

    /// Constructs a dictionary of pixel parameters used for pixel events related to the experiment.
    ///
    /// This property creates a dictionary of key-value pairs for parameters to be passed with a pixel event.
    /// The key for the number of days enrolled is added if `daysEnrolled` has a valid value. If there are no valid parameters,
    /// it returns `nil` to indicate that no parameters are needed for the event.
    var pixelParameters: [String: String]? {
        var parameters: [String: String] = [:]

        if let daysEnrolled = daysEnrolled {
            parameters[PixelKeys.daysEnrolled] = daysEnrolled
        }

        return parameters.isEmpty ? nil : parameters
    }

    /// Assigns the user to a cohort (`control` or `treatment`) if eligible and not already enrolled.
    func assignUserToCohort() {
        guard shouldEnroll else { return }

        let cohort: Cohort = Bool.random() ? .control : .treatment
        userDefaults.experimentCohort = cohort
        userDefaults.enrollmentDate = Date()

        Logger.freemiumDBP.debug("[Freemium DBP] User enrolled to cohort: \(cohort.rawValue)")
    }
}

// MARK: - FreemiumDBPPixelExperimentManager Private Extension

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

    /// Retrieves the user's assigned experiment cohort from `UserDefaults`.
    var experimentCohort: Cohort? {
        userDefaults.experimentCohort
    }

    /// Calculates the number of days the user has been enrolled in the experiment.
    ///
    /// This property retrieves the enrollment date from `UserDefaults.dbp.enrollmentDate`, and if available, computes the number
    /// of days from that date to the current date using the `Calendar.days(from:to:)` method. Returns `nil` if there is no
    /// enrollment date.
    var daysEnrolled: String? {
        guard let enrollmentDate = userDefaults.enrollmentDate else { return nil }
        return Calendar.days(from: enrollmentDate, to: Date())
    }
}

// MARK: - Other Extensions

private extension Calendar {

    /// Calculates the number of days between two dates.
    ///
    /// Uses the current `Calendar` to compute the difference in days between the `from` date and the `to` date.
    /// If the difference in days cannot be determined, returns `nil`.
    ///
    /// - Parameters:
    ///   - from: The start date.
    ///   - to: The end date.
    /// - Returns: The number of days between the two dates as a `String`, or `nil` if the calculation fails.
    static func days(from: Date, to: Date) -> String? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: from, to: to)
        guard let days = components.day else { return nil }
        return String(days)
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
