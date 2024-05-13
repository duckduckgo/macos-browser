//
//  DataBrokerProtectionBackgroundActivityScheduler.swift
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
import Common
import BrowserServicesKit

public protocol DataBrokerProtectionBackgroundActivityScheduler {
    func startScheduler()
    var delegate: DataBrokerProtectionBackgroundActivitySchedulerDelegate? { get set }

    var lastTriggerTimestamp: Date? { get set }
}

public protocol DataBrokerProtectionBackgroundActivitySchedulerDelegate: AnyObject {
    func dataBrokerProtectionBackgroundActivitySchedulerDidTrigger(_ activityScheduler: DataBrokerProtectionBackgroundActivityScheduler)
}

public final class DefaultDataBrokerProtectionBackgroundActivityScheduler: DataBrokerProtectionBackgroundActivityScheduler {

    private enum SchedulerCycle {
        // Arbitrary numbers for now

        static let interval: TimeInterval = 20 * 60 // 20 minutes
        static let tolerance: TimeInterval = 10 * 60 // 10 minutes
    }

    private let activity: NSBackgroundActivityScheduler
    private let schedulerIdentifier = "com.duckduckgo.macos.browser.databroker-protection-scheduler"

    public weak var delegate: DataBrokerProtectionBackgroundActivitySchedulerDelegate?
    public var lastTriggerTimestamp: Date?

    public init() {
        activity = NSBackgroundActivityScheduler(identifier: schedulerIdentifier)
        activity.repeats = true
        activity.interval = SchedulerCycle.interval
        activity.tolerance = SchedulerCycle.tolerance
        activity.qualityOfService = QualityOfService.background
    }

    public func startScheduler() {
        activity.schedule { _ in

            self.lastTriggerTimestamp = Date()
            os_log("Scheduler running...", log: .dataBrokerProtection)
            self.delegate?.dataBrokerProtectionBackgroundActivitySchedulerDidTrigger(self)
        }
    }
}
