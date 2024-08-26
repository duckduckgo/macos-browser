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

/// A protocol for deciding whether to display onboarding and open the first video in the Duck Player.
protocol DuckPlayerOnboardingDecider {
    /// A boolean indicating whether the onboarding should be displayed.
    var canDisplayOnboarding: Bool { get }

    /// A boolean indicating whether the first video should be opened in the Duck Player.
    var shouldOpenFirstVideoOnDuckPlayer: Bool { get }

    /// Sets the onboarding as done.
    ///
    /// This method should be called when the onboarding has been completed.
    func setOnboardingAsDone()

    /// Sets the flag to open the first video in the Duck Player.
    ///
    /// This method should be called when user selects to use Duck Player during the onboarding
    func setOpenFirstVideoOnDuckPlayer()

    /// Sets the first video in the Duck Player as done.
    ///
    /// This method should be called when the first video has been opened in the Duck Player.
    func setFirstVideoInDuckPlayerAsDone()

    /// Resets the onboarding and video flags to their initial state.
    ///
    /// This method should be called when the onboarding and video flags need to be reset.
    func reset()
}


struct DefaultDuckPlayerOnboardingDecider: DuckPlayerOnboardingDecider {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var canDisplayOnboarding: Bool {
        return !defaults.onboardingWasDisplayed
    }

    var shouldOpenFirstVideoOnDuckPlayer: Bool {
        return defaults.shouldOpenFirstVideoInDuckPlayer && !defaults.firstVideoWasOpenedInDuckPlayer
    }

    func setOnboardingAsDone() {
        defaults.onboardingWasDisplayed = true
    }

    func setOpenFirstVideoOnDuckPlayer() {
        defaults.shouldOpenFirstVideoInDuckPlayer = true
    }

    func setFirstVideoInDuckPlayerAsDone() {
        defaults.firstVideoWasOpenedInDuckPlayer = true
    }

    func reset() {
        defaults.onboardingWasDisplayed = false
        defaults.shouldOpenFirstVideoInDuckPlayer = false
        defaults.firstVideoWasOpenedInDuckPlayer = false
    }
}

private extension UserDefaults {
    enum Keys {
        static let onboardingWasDisplayed = "duckplayer.onboarding-displayed"
        static let firstVideoWasOpenedInDuckPlayer = "duckplayer.onboarding.first-video-opened"
        static let shouldOpenFirstVideoInDuckPlayer = "duckplayer.onboarding.should-open-in-duckplayer"
    }

    var onboardingWasDisplayed: Bool {
        get { return bool(forKey: Keys.onboardingWasDisplayed) }
        set { set(newValue, forKey: Keys.onboardingWasDisplayed) }
    }

    var firstVideoWasOpenedInDuckPlayer: Bool {
        get { return bool(forKey: Keys.firstVideoWasOpenedInDuckPlayer) }
        set { set(newValue, forKey: Keys.firstVideoWasOpenedInDuckPlayer) }
    }

    var shouldOpenFirstVideoInDuckPlayer: Bool {
        get { return bool(forKey: Keys.shouldOpenFirstVideoInDuckPlayer) }
        set { set(newValue, forKey: Keys.shouldOpenFirstVideoInDuckPlayer) }
    }
}
