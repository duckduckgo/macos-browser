//
//  FreemiumPIRUserStateManager.swift
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

/// A structure representing the results of a Freemium DBP match, including the count of matches and brokers.
public struct FreemiumDBPMatchResults: Codable {

    /// The number of matches found during the Freemium DBP process.
    public let matchesCount: Int

    /// The number of brokers involved in the Freemium DBP match.
    public let brokerCount: Int

    /// Initializes a new instance of `FreemiumDBPMatchResults`.
    ///
    /// - Parameters:
    ///   - matchesCount: The number of matches found.
    ///   - brokerCount: The number of brokers involved.
    public init(matchesCount: Int, brokerCount: Int) {
        self.matchesCount = matchesCount
        self.brokerCount = brokerCount
    }
}

/// Protocol that manages the user's state in the FreemiumPIR feature.
///
/// The properties in this protocol represent the various states and milestones in the user journey,
/// such as whether onboarding is complete, notifications have been posted, and important timestamps or data points.
///
/// Conforming types are responsible for persisting and retrieving these values.
public protocol FreemiumPIRUserStateManager {

    /// A boolean value indicating whether the user has completed the onboarding process.
    var didOnboard: Bool { get set }

    /// A boolean value indicating whether the "First Profile Saved" notification has been posted.
    var didPostFirstProfileSavedNotification: Bool { get set }

    /// A boolean value indicating whether the results notification has been posted.
    var didPostResultsNotification: Bool { get set }

    /// A boolean value indicating whether the user has dismissed the homepage promotion.
    var didDismissHomePagePromotion: Bool { get set }

    /// A string value that stores the timestamp of when the user saved their first profile.
    var firstProfileSavedTimestamp: String? { get set }

    /// The results of the user's first scan, stored as a `FreemiumDBPMatchResults` object.
    var firstScanResults: FreemiumDBPMatchResults? { get set }
}

/// Default implementation of `FreemiumPIRUserStateManager` that uses `UserDefaults` for underlying storage.
///
/// Each property in this class corresponds to a specific `UserDefaults` key to maintain persistence across app sessions.
public final class DefaultFreemiumPIRUserStateManager: FreemiumPIRUserStateManager {

    /// Keys for storing the values in `UserDefaults`.
    private enum Keys {
        static let didOnboard = "macos.browser.freemium.pir.did.onboard"
        static let didPostFirstProfileSavedNotification = "macos.browser.freemium.pir.did.post.first.profile.saved.notification"
        static let didPostResultsNotification = "macos.browser.freemium.pir.did.post.results.notification"
        static let didDismissHomePagePromotion = "macos.browser.freemium.pir.did.post.dismiss.home.page.promotion"
        static let firstProfileSavedTimestamp = "macos.browser.freemium.pir.first.profile.saved.timestamp"
        static let firstScanResults = "macos.browser.freemium.pir.first.scan.results"
    }

    private let userDefaults: UserDefaults

    // MARK: - FreemiumPIRUserStateManager Properties

    /// Tracks whether the user has completed the onboarding process.
    ///
    /// - Uses the `UserDefaults` key: `macos.browser.freemium.pir.did.onboard`.
    public var didOnboard: Bool {
        get {
            userDefaults.bool(forKey: Keys.didOnboard)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.didOnboard)
        }
    }

    /// Tracks the timestamp of when the user saved their first profile.
    ///
    /// - Uses the `UserDefaults` key: `macos.browser.freemium.pir.first.profile.saved.timestamp`.
    public var firstProfileSavedTimestamp: String? {
        get {
            userDefaults.value(forKey: Keys.firstProfileSavedTimestamp) as? String
        }
        set {
            userDefaults.set(newValue, forKey: Keys.firstProfileSavedTimestamp)
        }
    }

    /// Tracks whether the "First Profile Saved" notification has been posted.
    ///
    /// - Uses the `UserDefaults` key: `macos.browser.freemium.pir.did.post.first.profile.saved.notification`.
    public var didPostFirstProfileSavedNotification: Bool {
        get {
            userDefaults.bool(forKey: Keys.didPostFirstProfileSavedNotification)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.didPostFirstProfileSavedNotification)
        }
    }

    /// Tracks whether the results notification has been posted.
    ///
    /// - Uses the `UserDefaults` key: `macos.browser.freemium.pir.did.post.results.notification`.
    public var didPostResultsNotification: Bool {
        get {
            userDefaults.bool(forKey: Keys.didPostResultsNotification)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.didPostResultsNotification)
        }
    }

    /// Tracks the results of the user's first scan.
    ///
    /// This value is stored as a `FreemiumDBPMatchResults` object, encoded and decoded using `JSONEncoder` and `JSONDecoder`.
    /// - Uses the `UserDefaults` key: `macos.browser.freemium.pir.first.scan.results`.
    public var firstScanResults: FreemiumDBPMatchResults? {
        get {
            guard let data = userDefaults.object(forKey: Keys.firstScanResults) as? Data,
                  let decoded = try? JSONDecoder().decode(FreemiumDBPMatchResults.self, from: data) else { return nil }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                userDefaults.set(encoded, forKey: Keys.firstScanResults)
            }
        }
    }

    /// Tracks whether the user has dismissed the homepage promotion.
    ///
    /// - Uses the `UserDefaults` key: `macos.browser.freemium.pir.did.post.dismiss.home.page.promotion`.
    public var didDismissHomePagePromotion: Bool {
        get {
            userDefaults.bool(forKey: Keys.didDismissHomePagePromotion)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.didDismissHomePagePromotion)
        }
    }

    // MARK: - Initialization

    /// Initializes a new instance of `DefaultFreemiumPIRUserStateManager`.
    ///
    /// - Parameter userDefaults: The `UserDefaults` instance used to store and retrieve the user's state data.
    ///
    /// - Note: Ensure the same `UserDefaults` instance is passed throughout the app to maintain consistency in state management.
    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
}
