//
//  FreemiumDBPUserStateManager.swift
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
public struct FreemiumDBPMatchResults: Codable, Equatable {

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

/// Protocol that manages the user's state in the FreemiumDBP feature.
///
/// The properties in this protocol represent the various states and milestones in the user journey,
/// such as whether Freemium is activated (i.e was accessed), notifications have been posted, and important timestamps or data points.
///
/// Conforming types are responsible for persisting and retrieving these values.
public protocol FreemiumDBPUserStateManager {

    /// A boolean value indicating whether the user has accessed the Freemium DBP feature
    var didActivate: Bool { get set }

    /// A boolean value indicating whether the "First Profile Saved" notification has been posted.
    var didPostFirstProfileSavedNotification: Bool { get set }

    /// A boolean value indicating whether the results notification has been posted.
    var didPostResultsNotification: Bool { get set }

    /// A boolean value indicating whether the user has dismissed the homepage promotion.
    var didDismissHomePagePromotion: Bool { get set }

    /// A Date value that stores the timestamp of when the user saved their first profile.
    var firstProfileSavedTimestamp: Date? { get set }

    /// The results of the user's first scan, stored as a `FreemiumDBPMatchResults` object.
    var firstScanResults: FreemiumDBPMatchResults? { get set }

    /// A Date value that stores the timestamp of when the user upgraded from Freemium to a Paid Subscription
    var upgradeToSubscriptionTimestamp: Date? { get set }

    /// Resets all stored user state
    func resetAllState()
}

/// Default implementation of `FreemiumDBPUserStateManager` that uses `UserDefaults` for underlying storage.
///
/// Each property in this class corresponds to a specific `UserDefaults` key to maintain persistence across app sessions.
public final class DefaultFreemiumDBPUserStateManager: FreemiumDBPUserStateManager {

    /// Keys for storing the values in `UserDefaults`.
    private enum Keys {
        static let didActivate = "macos.browser.freemium.dbp.did.activate"
        static let didPostFirstProfileSavedNotification = "macos.browser.freemium.dbp.did.post.first.profile.saved.notification"
        static let didPostResultsNotification = "macos.browser.freemium.dbp.did.post.results.notification"
        static let didDismissHomePagePromotion = "macos.browser.freemium.dbp.did.post.dismiss.home.page.promotion"
        static let firstProfileSavedTimestamp = "macos.browser.freemium.dbp.first.profile.saved.timestamp"
        static let firstScanResults = "macos.browser.freemium.dbp.first.scan.results"
        static let upgradeToSubscriptionTimestamp = "macos.browser.freemium.dbp.upgrade.to.subscription.timestamp"
    }

    private let userDefaults: UserDefaults

    // MARK: - FreemiumDBPUserStateManager Properties

    /// Tracks whether the user has accessed the Freemium DBP feature.
    ///
    /// - Uses the `UserDefaults` key: `macos.browser.freemium.dbp.did.activate`.
    public var didActivate: Bool {
        get {
            userDefaults.bool(forKey: Keys.didActivate)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.didActivate)
        }
    }

    /// Tracks the timestamp of when the user saved their first profile.
    ///
    /// - Uses the `UserDefaults` key: `macos.browser.freemium.dbp.first.profile.saved.timestamp`.
    public var firstProfileSavedTimestamp: Date? {
        get {
            userDefaults.value(forKey: Keys.firstProfileSavedTimestamp) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: Keys.firstProfileSavedTimestamp)
        }
    }

    /// Tracks whether the "First Profile Saved" notification has been posted.
    ///
    /// - Uses the `UserDefaults` key: `macos.browser.freemium.dbp.did.post.first.profile.saved.notification`.
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
    /// - Uses the `UserDefaults` key: `macos.browser.freemium.dbp.did.post.results.notification`.
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
    /// - Uses the `UserDefaults` key: `macos.browser.freemium.dbp.first.scan.results`.
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
    /// - Uses the `UserDefaults` key: `macos.browser.freemium.dbp.did.post.dismiss.home.page.promotion`.
    public var didDismissHomePagePromotion: Bool {
        get {
            userDefaults.bool(forKey: Keys.didDismissHomePagePromotion)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.didDismissHomePagePromotion)
        }
    }

    /// Tracks the timestamp of when the user upgraded from Freemium to paid Subscription.
    ///
    /// - Uses the `UserDefaults` key: `macos.browser.freemium.dbp.upgrade.to.subscription.timestamp`.
    public var upgradeToSubscriptionTimestamp: Date? {
        get {
            userDefaults.value(forKey: Keys.upgradeToSubscriptionTimestamp) as? Date
        }
        set {
            userDefaults.set(newValue, forKey: Keys.upgradeToSubscriptionTimestamp)
        }
    }

    // MARK: - Initialization

    /// Initializes a new instance of `DefaultFreemiumDBPUserStateManager`.
    ///
    /// - Parameter userDefaults: The `UserDefaults` instance used to store and retrieve the user's state data.
    ///
    /// - Note: Ensure the same `UserDefaults` instance is passed throughout the app to maintain consistency in state management.
    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    /// Resets all stored user state by clearing or resetting the relevant keys in `UserDefaults`.
    public func resetAllState() {
        // Reset each stored value to its default state
        userDefaults.removeObject(forKey: Keys.didActivate)
        userDefaults.removeObject(forKey: Keys.firstProfileSavedTimestamp)
        userDefaults.removeObject(forKey: Keys.didPostFirstProfileSavedNotification)
        userDefaults.removeObject(forKey: Keys.didPostResultsNotification)
        userDefaults.removeObject(forKey: Keys.firstScanResults)
        userDefaults.removeObject(forKey: Keys.didDismissHomePagePromotion)
        userDefaults.removeObject(forKey: Keys.upgradeToSubscriptionTimestamp)
    }
}
