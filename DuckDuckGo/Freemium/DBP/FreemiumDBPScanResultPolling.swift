//
//  FreemiumDBPScanResultPolling.swift
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
import OSLog

/// Protocol defining the interface for DBP scan result polling.
protocol FreemiumDBPScanResultPolling {
    /// Starts the polling process for scan results or begins observing for profile saved events.
    func startPollingOrObserving()
}

/// A class that manages the polling for DBP scan results and handles posting notifications for results.
/// It either starts polling if a profile has been saved or begins observing for the event of saving a profile.
/// The polling checks for results periodically and posts notifications when results are found or no results are found after a set duration.
final class DefaultFreemiumDBPScanResultPolling: FreemiumDBPScanResultPolling {

    /// Internal for testing purposes to allow access in test cases.
    var timer: Timer?

    private var observer: Any?

    private let dataManager: DataBrokerProtectionDataManaging
    private var freemiumDBPUserStateManager: FreemiumDBPUserStateManager
    private let notificationCenter: NotificationCenter
    private let timerInterval: TimeInterval
    private let maxCheckDuration: TimeInterval

    /// Initializes the `DefaultFreemiumDBPScanResultPolling` instance with the necessary dependencies.
    ///
    /// - Parameters:
    ///   - dataManager: The data manager responsible for managing broker protection data.
    ///   - freemiumDBPUserStateManager: Manages the state of the user's profile in Freemium DBP.
    ///   - notificationCenter: The notification center used for posting and observing notifications. Defaults to `.default`.
    ///   - timerInterval: The interval in seconds between polling checks. Defaults to 30 mins.
    ///   - maxCheckDuration: The maximum time allowed before stopping polling without results. Defaults to 24 hours.
    init(
        dataManager: DataBrokerProtectionDataManaging,
        freemiumDBPUserStateManager: FreemiumDBPUserStateManager,
        notificationCenter: NotificationCenter = .default,
        timerInterval: TimeInterval = 1800,  // 30 mins in seconds
        maxCheckDuration: TimeInterval = 86400  // 24 hours in seconds
    ) {
        self.dataManager = dataManager
        self.freemiumDBPUserStateManager = freemiumDBPUserStateManager
        self.notificationCenter = notificationCenter
        self.timerInterval = timerInterval
        self.maxCheckDuration = maxCheckDuration
    }

    // MARK: - Public Methods

    /// Starts polling for DBP scan results or observes for a profile saved notification if no profile has been saved yet.
    func startPollingOrObserving() {
        guard !freemiumDBPUserStateManager.didPostResultsNotification else { return }

        if firstProfileSaved {
            startPolling()
        } else {
            startObserving()
        }
    }

    deinit {
        stopObserving()
        stopTimer()
    }
}

private extension DefaultFreemiumDBPScanResultPolling {

    /// A Boolean value indicating whether the first profile has been saved.
    var firstProfileSaved: Bool {
        freemiumDBPUserStateManager.firstProfileSavedTimestamp != nil
    }

    /// The saved timestamp of the first profile as a `Date`, or `nil` if no profile has been saved yet.
    var firstProfileSavedTimestamp: Date? {
        get {
            freemiumDBPUserStateManager.firstProfileSavedTimestamp
        }
        set {
            freemiumDBPUserStateManager.firstProfileSavedTimestamp = newValue
        }
    }

    /// Starts the polling process for DBP scan results.
    ///
    /// It first checks if any results are available.
    /// If no results are found, it starts a repeating timer to poll for results at regular intervals.
    func startPolling() {
        Logger.freemiumDBP.debug("[Freemium DBP] Starting to Poll for Scan Results")
        checkResultsAndNotifyIfApplicable()
        startPollingTimer()
    }

    /// Starts observing for the profile saved notification.
    func startObserving() {
        Logger.freemiumDBP.debug("[Freemium DBP] Starting to Observe for Profile Saved Notifications")
        observeProfileSavedNotification()
    }

    /// Observes the notification for when the first profile is saved and triggers the polling process.
    func observeProfileSavedNotification() {
        observer = notificationCenter.addObserver(
            forName: .pirProfileSaved,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Logger.freemiumDBP.debug("[Freemium DBP] Profile Saved Notification Received")
            self?.profileSavedNotificationReceived()
        }
    }

    /// Called when the profile saved notification is received. Saves the current timestamp and starts polling for results.
    func profileSavedNotificationReceived() {
        if !firstProfileSaved {
            saveCurrentTimestamp()
        }
        startPollingTimer()
    }

    /// Saves the current timestamp as the time when the first profile was saved.
    func saveCurrentTimestamp() {
        firstProfileSavedTimestamp = Date()
    }

    /// Starts a timer that polls for results at regular intervals, ensuring the timer is not already running.
    func startPollingTimer() {
        guard timer == nil, !freemiumDBPUserStateManager.didPostResultsNotification else { return }

        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] _ in
            self?.checkResultsAndNotifyIfApplicable()
        }
    }

    /// Checks if any matches have been found or if the maximum polling duration has been exceeded.
    /// Posts a notification if results are found or if no results are found after the maximum duration.
    func checkResultsAndNotifyIfApplicable() {
        guard let firstProfileSavedTimestamp = firstProfileSavedTimestamp else { return }

        let currentDate = Date()
        let elapsedTime = currentDate.timeIntervalSince(firstProfileSavedTimestamp)

        let (matchesCount, brokerCount) = (try? dataManager.matchesFoundAndBrokersCount()) ?? (0, 0)

        if matchesCount > 0 || elapsedTime >= maxCheckDuration{
            notifyOfResultsAndStopTimer(matchesCount, brokerCount)
        }
    }

    /// Notifies the system of scan results and stops the polling timer.
    ///
    /// This method posts a notification with the results, either with or without matches, and updates the user's
    /// state to reflect that the results have been posted. Finally, it stops the polling timer.
    ///
    /// - Parameters:
    ///   - matchesCount: The number of matches found during the scan.
    ///   - brokerCount: The number of brokers associated with the matches found.
    func notifyOfResultsAndStopTimer(_ matchesCount: Int, _ brokerCount: Int) {

        freemiumDBPUserStateManager.firstScanResults = FreemiumDBPMatchResults(matchesCount: matchesCount, brokerCount: brokerCount)
        let withOrWith = matchesCount > 0 ? "WITH" : "WITHOUT"
        Logger.freemiumDBP.debug("[Freemium DBP] Posting Scan Results Notification \(withOrWith) matches")

        notificationCenter.post(name: .freemiumDBPResultPollingComplete, object: nil)

        freemiumDBPUserStateManager.didPostResultsNotification = true
        stopTimer()
    }

    /// Stops observing `pirProfileSaved` notifications.
    func stopObserving() {
        if let observer = observer {
            notificationCenter.removeObserver(observer)
        }
    }

    /// Stops the polling timer and clears the timer reference.
    func stopTimer() {
        Logger.freemiumDBP.debug("[Freemium DBP] Stopping Polling Timer")
        timer?.invalidate()
        timer = nil
    }
}
