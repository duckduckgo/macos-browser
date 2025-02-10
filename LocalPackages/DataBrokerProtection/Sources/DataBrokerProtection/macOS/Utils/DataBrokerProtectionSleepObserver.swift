//
//  DataBrokerProtectionSleepObserver.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Cocoa
import Common
import os.log

protocol SleepObserver {
    func totalSleepTime() -> TimeInterval
}
/// This class purpose is to measure from the background agent how much time the operations
/// are working while the computer is asleep.
/// This will help us gather metrics around what happen to WebViews when the computer is sleeping.
///
/// https://app.asana.com/0/1204006570077678/1207278682082256/f
final class DataBrokerProtectionSleepObserver: SleepObserver {
    private var startSleepTime: Date?
    private var endTime: TimeInterval?
    private let brokerProfileQueryData: BrokerProfileQueryData

    init(brokerProfileQueryData: BrokerProfileQueryData) {
        self.brokerProfileQueryData = brokerProfileQueryData
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleepNotification(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWakeNotification(_:)), name: NSWorkspace.didWakeNotification, object: nil)
    }

    deinit {
        Logger.dataBrokerProtection.log("SleepObserver: Deinit \(self.brokerProfileQueryData.dataBroker.name, privacy: .public) \(self.brokerProfileQueryData.profileQuery.firstName, privacy: .public) \(self.brokerProfileQueryData.profileQuery.city, privacy: .public)")
        NotificationCenter.default.removeObserver(self)
    }

    func totalSleepTime() -> TimeInterval {
        guard let totalSleepTime = self.endTime else {
            return 0
        }

        Logger.dataBrokerProtection.log("SleepObserver: Total Sleep time more than zero: \(String(totalSleepTime), privacy: .public)")

        return totalSleepTime
    }

    @objc func willSleepNotification(_ notification: Notification) {
        Logger.dataBrokerProtection.log("SleepObserver: Computer will sleep on \(self.brokerProfileQueryData.dataBroker.name, privacy: .public) \(self.brokerProfileQueryData.profileQuery.firstName, privacy: .public) \(self.brokerProfileQueryData.profileQuery.city, privacy: .public)")
        startSleepTime = Date()
    }

    @objc func didWakeNotification(_ notification: Notification) {
        Logger.dataBrokerProtection.log("SleepObserver: Computer waking up \(self.brokerProfileQueryData.dataBroker.name, privacy: .public) \(self.brokerProfileQueryData.profileQuery.firstName, privacy: .public) \(self.brokerProfileQueryData.profileQuery.city, privacy: .public)")
        guard let startSleepTime = self.startSleepTime else {
            return
        }

        if let endTime = self.endTime {
            // This scenario can happen if during the scan the computer goes to sleep more than once.
            let currentSleepIterationTime = Date().timeIntervalSince(startSleepTime).toMs
            self.endTime = endTime + currentSleepIterationTime
        } else {
            endTime = Date().timeIntervalSince(startSleepTime).toMs
        }
    }
}

extension TimeInterval {
    var toMs: TimeInterval {
        (self * 1000).rounded(.towardZero)
    }
}
