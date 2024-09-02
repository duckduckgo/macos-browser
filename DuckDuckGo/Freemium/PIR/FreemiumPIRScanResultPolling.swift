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

extension Notification.Name {
    static let pirResultsFound = Notification.Name("pirResultsFound") // New notification for results found
    static let pirNoResultsFound = Notification.Name("pirNoResultsFound") // New notification for no results after 24 hours
}

final class DefaultFreemiumPIRScanResultPolling {

    private let key = "macos.browser.freemium.pir.profile.saved.timestamp"
    private var observer: Any?
    private var timer: Timer?
    private let pirScanResults: PIRScanResults
    private let userDefaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private let timerInterval: TimeInterval
    private let maxCheckDuration: TimeInterval

    init(
        pirScanResults: PIRScanResults = DefaultPIRScanResults(),
        userDefaults: UserDefaults = .dbp,
        notificationCenter: NotificationCenter = .default,
        timerInterval: TimeInterval = 3600,  // 1 hour interval
        maxCheckDuration: TimeInterval = 86400  // 24 hours in seconds
    ) {
        self.pirScanResults = pirScanResults
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
        self.timerInterval = timerInterval
        self.maxCheckDuration = maxCheckDuration

        if firstProfileSaved {
            checkCondition()               // Immediate condition check
            startRepeatingConditionCheck()  // Start the timer for subsequent checks
        } else {
            observeNotification()          // Wait for notification if profile not saved
        }
    }
}

private extension DefaultFreemiumPIRScanResultPolling {

    var firstProfileSaved: Bool {
        userDefaults.string(forKey: key) != nil
    }

    var profileSavedTimestamp: Date? {
        get {
            guard let timestampString = userDefaults.string(forKey: key) else { return nil }
            return makeDateFormatter().date(from: timestampString)
        }
        set {
            if let newTimestamp = newValue {
                let dateFormatter = makeDateFormatter()
                let timestampString = dateFormatter.string(from: newTimestamp)
                userDefaults.set(timestampString, forKey: key)
            } else {
                userDefaults.removeObject(forKey: key)
            }
        }
    }

    func observeNotification() {
        observer = notificationCenter.addObserver(
            forName: .pirFirstProfileSaved,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.notificationReceived()
        }
    }

    func notificationReceived() {
        if !firstProfileSaved {
            saveCurrentTimestamp()
        }
        startRepeatingConditionCheck()
    }

    func saveCurrentTimestamp() {
        profileSavedTimestamp = Date()
    }

    func startRepeatingConditionCheck() {
        if profileSavedTimestamp == nil {
            profileSavedTimestamp = Date()
        }
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] _ in
            self?.checkCondition()
        }
    }

    func checkCondition() {
        guard let profileSavedTimestamp = profileSavedTimestamp else { return }
        let currentDate = Date()
        let elapsedTime = currentDate.timeIntervalSince(profileSavedTimestamp)

        let matchesFoundCount = pirScanResults.matchesFoundCount()

        if matchesFoundCount > 0 {
            notificationCenter.post(name: .pirResultsFound, object: nil)
            timer?.invalidate()  // Stop the timer after the notification is posted
        } else if elapsedTime >= maxCheckDuration {
            notificationCenter.post(name: .pirNoResultsFound, object: nil)
            timer?.invalidate()  // Stop the timer after the fallback notification is posted
        }
    }

    func makeDateFormatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        dateFormatter.dateStyle = .none
        return dateFormatter
    }
}
