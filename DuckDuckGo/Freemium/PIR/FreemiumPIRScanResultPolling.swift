//
//  FreemiumPIRScanResultPolling.swift
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
import DataBrokerProtection
import Freemium

extension Notification.Name {
    /// Notification posted when the first profile is saved.
    static let pirFirstProfileSaved = Notification.Name("pirFirstProfileSaved")

    /// Notification posted when results are found after polling for profile matches.
    static let pirResultsFound = Notification.Name("pirResultsFound")

    /// Notification posted when no results are found after polling for profile matches and the maximum check duration is exceeded.
    static let pirNoResultsFound = Notification.Name("pirNoResultsFound")
}

/// Protocol defining the interface for PIR (Profile Information Removal) scan result polling.
protocol FreemiumPIRScanResultPolling {
    /// Starts the polling process for scan results or begins observing for profile saved events.
    func startPollingOrObserving()
}

/// A class that manages the polling for PIR (Profile Information Removal) scan results and handles posting notifications for results.
/// It either starts polling if a profile has been saved or begins observing for the event of saving a profile.
/// The polling checks for results periodically and posts notifications when results are found or no results are found after a set duration.
final class DefaultFreemiumPIRScanResultPolling: FreemiumPIRScanResultPolling {

    /// - Internal for testing purposes to allow access in test cases.
    var timer: Timer?

    private var observer: Any?

    private let dataManager: DataBrokerProtectionDataManaging
    private var freemiumPIRUserStateManager: FreemiumPIRUserStateManager
    private let notificationCenter: NotificationCenter
    private let timerInterval: TimeInterval
    private let dateFormatter: DateFormatter
    private let maxCheckDuration: TimeInterval

    /// Initializes the `DefaultFreemiumPIRScanResultPolling` instance with the necessary dependencies.
    ///
    /// - Parameters:
    ///   - dataManager: The data manager responsible for managing broker protection data.
    ///   - freemiumPIRUserStateManager: Manages the state of the user's profile in Freemium PIR.
    ///   - notificationCenter: The notification center used for posting and observing notifications. Defaults to `.default`.
    ///   - timerInterval: The interval in seconds between polling checks. Defaults to 1 hour.
    ///   - maxCheckDuration: The maximum time allowed before stopping polling without results. Defaults to 24 hours.
    ///   - dateFormatter: A `DateFormatter` for formatting dates. Defaults to a POSIX date-time formatter.
    init(
        dataManager: DataBrokerProtectionDataManaging,
        freemiumPIRUserStateManager: FreemiumPIRUserStateManager,
        notificationCenter: NotificationCenter = .default,
        timerInterval: TimeInterval = 3600,  // 1 hour interval
        maxCheckDuration: TimeInterval = 86400,  // 24 hours in seconds
        dateFormatter: DateFormatter = DefaultFreemiumPIRScanResultPolling.makePOSIXDateTimeFormatter()
    ) {
        self.dataManager = dataManager
        self.freemiumPIRUserStateManager = freemiumPIRUserStateManager
        self.notificationCenter = notificationCenter
        self.timerInterval = timerInterval
        self.maxCheckDuration = maxCheckDuration
        self.dateFormatter = dateFormatter
    }

    /// Starts polling for PIR scan results or observes for a profile saved notification if no profile has been saved yet.
    func startPollingOrObserving() {
        if firstProfileSaved {
            startRepeatingConditionCheck()
        } else {
            observeNotification()
        }
    }

    deinit {
        if let observer = observer {
            notificationCenter.removeObserver(observer)
        }
        timer?.invalidate()
    }
}

private extension DefaultFreemiumPIRScanResultPolling {

    /// A Boolean value indicating whether the first profile has been saved.
    var firstProfileSaved: Bool {
        freemiumPIRUserStateManager.profileSavedTimestamp != nil
    }

    /// The saved timestamp of the first profile as a `Date`, or `nil` if no profile has been saved yet.
    var profileSavedTimestamp: Date? {
        get {
            guard let timestampString = freemiumPIRUserStateManager.profileSavedTimestamp else { return nil }
            return dateFormatter.date(from: timestampString)
        }
        set {
            if let newTimestamp = newValue {
                let timestampString = dateFormatter.string(from: newTimestamp)
                freemiumPIRUserStateManager.profileSavedTimestamp = timestampString
            } else {
                freemiumPIRUserStateManager.profileSavedTimestamp = nil
            }
        }
    }

    /// Observes the notification for when the first profile is saved and triggers the polling process.
    func observeNotification() {
        observer = notificationCenter.addObserver(
            forName: .pirFirstProfileSaved,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notificationReceived()
        }
    }

    /// Called when the profile saved notification is received. Saves the current timestamp and starts polling for results.
    func notificationReceived() {
        if !firstProfileSaved {
            saveCurrentTimestamp()
        }
        startRepeatingConditionCheck()
    }

    /// Saves the current timestamp as the time when the first profile was saved.
    func saveCurrentTimestamp() {
        profileSavedTimestamp = Date()
    }

    /// Starts a timer that polls for results at regular intervals, ensuring the timer is not already running.
    func startRepeatingConditionCheck() {
        guard timer == nil else { return }

        if profileSavedTimestamp == nil {
            saveCurrentTimestamp()
        }

        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] _ in
            self?.checkCondition()
        }

        timer?.fire()
    }

    /// Checks if any matches have been found or if the maximum polling duration has been exceeded.
    /// Posts a notification if results are found or if no results are found after the maximum duration.
    func checkCondition() {
        guard let profileSavedTimestamp = profileSavedTimestamp else { return }
        let currentDate = Date()
        let elapsedTime = currentDate.timeIntervalSince(profileSavedTimestamp)

        let matchesFoundCount = (try? dataManager.matchesFoundCount()) ?? 0

        if matchesFoundCount > 0 {
            notificationCenter.post(name: .pirResultsFound, object: nil)
            stopTimer()
        } else if elapsedTime >= maxCheckDuration {
            notificationCenter.post(name: .pirNoResultsFound, object: nil)
            stopTimer()
        }
    }

    /// Stops the polling timer and clears the timer reference.
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Creates a POSIX-compliant `DateFormatter` that formats date-time strings in the "yyyy-MM-dd HH:mm:ss" format.
    ///
    /// - Returns: A `DateFormatter` set to the POSIX locale and GMT time zone.
    static func makePOSIXDateTimeFormatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter
    }
}
