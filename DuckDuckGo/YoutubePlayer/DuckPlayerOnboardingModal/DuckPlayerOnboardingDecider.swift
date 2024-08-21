//
//  DuckPlayerOnboardingDecider.swift
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

protocol DuckPlayerOnboardingDecider {
    var canDisplayOnboarding: Bool { get }
    var shouldOpenFirstVideoOnDuckPlayer: Bool { get }

    func setOnboardingAsDone()
    func setOpenFirstVideoOnDuckPlayer()
    func setFirstVideoInDuckPlayerAsDone()

    func reset()
}

// WIP
struct DefaultDuckPlayerOnboardingDecider: DuckPlayerOnboardingDecider {
    private let defaults = UserDefaults.standard
    private let onboardingKey = "DuckPlayerOnboardingDone"
    private let firstVideoKey = "FirstVideoInDuckPlayerOpened"
    private let firstVideoDoneKey = "FirstVideoInDuckPlayerDone"

    var canDisplayOnboarding: Bool {
        return !defaults.bool(forKey: onboardingKey)
    }

    var shouldOpenFirstVideoOnDuckPlayer: Bool {
        return defaults.bool(forKey: firstVideoKey) && !defaults.bool(forKey: firstVideoDoneKey)
    }

    func setOnboardingAsDone() {
        defaults.set(true, forKey: onboardingKey)
    }

    func setOpenFirstVideoOnDuckPlayer() {
        defaults.set(true, forKey: firstVideoKey)
    }

    func setFirstVideoInDuckPlayerAsDone() {
        defaults.set(true, forKey: firstVideoDoneKey)
    }

    func reset() {
         defaults.removeObject(forKey: onboardingKey)
         defaults.removeObject(forKey: firstVideoKey)
         defaults.removeObject(forKey: firstVideoDoneKey)
     }
}
