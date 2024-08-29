//
//  QuartzIdleStateProvider.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import CoreGraphics
import os.log

final class QuartzIdleStateProvider: DeviceIdleStateProvider {

    func secondsSinceLastEvent() -> TimeInterval {
        let anyInputEventType = CGEventType(rawValue: ~0)!
        let seconds = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInputEventType)

        Logger.autoLock.debug("Idle duration since last user input event: \(seconds)")

        return seconds
    }

}
