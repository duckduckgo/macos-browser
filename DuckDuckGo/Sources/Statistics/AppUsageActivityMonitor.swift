//
//  AppUsageActivityMonitor.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Cocoa
import Combine

protocol AppUsageActivityMonitorDelegate: AnyObject {
    func countOpenWindowsAndTabs() -> [Int]
    func activeUsageTimeHasReachedThreshold(avgTabCount: Double)
}

final class AppUsageActivityMonitor: NSObject {

    private enum Constants {
        static let minute = 60.0
        static let hour = 60.0 * minute
        static let day = 24.0 * hour

        static let throttle = 10.0
        static let maxIdleTime = 5.0 * minute
        static let threshold = hour

        static let usageTimeKey = "activityTime"
        static let activityDateKey = "activityDate"
        static let activityAvgTabsKey = "activityAvgTabs"
    }

    private let storage: PixelDataStore

    private var usageTime: TimeInterval {
        didSet {
            storage.set(Int(self.usageTime), forKey: Constants.usageTimeKey)
        }
    }
    private var lastActivityDate: TimeInterval {
        didSet {
            storage.set(Int(self.lastActivityDate), forKey: Constants.activityDateKey)
        }
    }
    private var avgTabCount: Double {
        didSet {
            storage.set(self.avgTabCount, forKey: Constants.activityAvgTabsKey)
        }
    }

    private let maxIdleTime: TimeInterval
    private let threshold: TimeInterval
    private let currentTime: () -> TimeInterval

    private weak var delegate: AppUsageActivityMonitorDelegate?

    private var monitor: Any?
    private var timer: Timer?

    init(delegate: AppUsageActivityMonitorDelegate,
         dateProvider: @escaping @autoclosure () -> TimeInterval = Date().timeIntervalSinceReferenceDate,
         storage: PixelDataStore = LocalPixelDataStore.shared,
         throttle: TimeInterval = Constants.throttle,
         maxIdleTime: TimeInterval = Constants.maxIdleTime,
         threshold: TimeInterval = Constants.threshold) {

        self.storage = storage

        self.maxIdleTime = maxIdleTime
        self.threshold = threshold

        self.usageTime = storage.value(forKey: Constants.usageTimeKey) ?? 0.0
        self.lastActivityDate = storage.value(forKey: Constants.activityDateKey) ?? 0.0
        self.avgTabCount = storage.value(forKey: Constants.activityAvgTabsKey) ?? 0.0
        self.currentTime = dateProvider
        self.delegate = delegate

        super.init()

        let kinds: NSEvent.EventTypeMask = [.keyDown, .mouseMoved, .scrollWheel]

        self.monitor = NSEvent.addLocalMonitorForEvents(matching: kinds) { [weak self] event in
            if let self = self, NSApp.isActive {

                if self.timer == nil, throttle > 0 {
                    self.timer = .scheduledTimer(withTimeInterval: throttle, repeats: false) { [weak self] _ in
                        self?.timer = nil
                        self?.monitorDidReceiveEvent()
                    }

                } else if throttle == 0 {
                    self.monitorDidReceiveEvent()
                }
            }
            return event
        }
    }

    private func countTabs() -> Double {
        guard let delegate = delegate else { return 0 }

        let uiInfo = delegate.countOpenWindowsAndTabs()
        return Double(uiInfo.reduce(0, +))
    }

    private func monitorDidReceiveEvent() {
        let currentTime = self.currentTime()
        let lastActivityDate = self.lastActivityDate
        let interval = currentTime - lastActivityDate

        self.lastActivityDate = currentTime

        if interval < maxIdleTime {
            // continuous active usage
            self.avgTabCount = (self.avgTabCount + self.countTabs()) / 2.0

            self.incrementUsageTime(by: interval)

        } else if Int(currentTime / Constants.day) != Int(lastActivityDate / Constants.day) {
            // reset on next day
            usageTime = 0
            self.avgTabCount = self.countTabs()
        }
    }

    private func incrementUsageTime(by interval: TimeInterval) {
        guard self.usageTime < self.threshold else { return }

        self.usageTime += interval
        if self.usageTime >= self.threshold {
            delegate?.activeUsageTimeHasReachedThreshold(avgTabCount: self.avgTabCount)
        }
    }

    deinit {
        NSEvent.removeMonitor(monitor!)
    }

}
