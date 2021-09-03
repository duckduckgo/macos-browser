//
//  OneTimePasswordTimer.swift
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

import Foundation
import Combine

final class OneTimePasswordTimer {

    static let timerProgressedNotification = Notification.Name("OneTimePasswordTimer.TimerProgressed")
    static let userInfoTimeRemainingKey = Notification.Name("OneTimePasswordTimer.TimeRemainingKey")
    static let userInfoProgressKey = Notification.Name("OneTimePasswordTimer.ProgressKey")

    static let shared = OneTimePasswordTimer()

    var remainder: TimeInterval = 0
    var percentComplete: Float = 0

    private var timer: Timer?

    func beginTimer() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
    }

    func timerTick() {
        let delta = Date().timeIntervalSince1970
        let period: TimeInterval = 30

        let progress = delta.truncatingRemainder(dividingBy: period)
        let warning = ceil(period - progress)
        let complete = Float(progress / period)

        remainder = TimeInterval(warning)
        percentComplete = complete

        let userInfo: [Notification.Name: Any] = [
            OneTimePasswordTimer.userInfoTimeRemainingKey: remainder,
            OneTimePasswordTimer.userInfoProgressKey: percentComplete
        ]
        NotificationCenter.default.post(name: OneTimePasswordTimer.timerProgressedNotification, object: nil, userInfo: userInfo)
    }

}
