//
//  OnboardingPixelReporter.swift
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
import Onboarding
import PixelKit

typealias OnboardingPixelReporting =
OnboardingSearchSuggestionsPixelReporting
& OnboardingSiteSuggestionsPixelReporting
& OnboardingDialogsReporting
& OnboardingAddressBarReporting

protocol OnboardingAddressBarReporting: AnyObject {
    func trackAddressBarTypedIn()
    func trackPrivacyDashboardOpened()
    func trackSiteVisited()
}

protocol OnboardingDialogsReporting: AnyObject {
    func trackFireButtonSkipped()
    func trackLastDialogShown()
    func trackFireButtonTryIt()
}

protocol OnboardingFireReporting: AnyObject {
    func trackFireButtonPressed()
}

final class OnboardingPixelReporter: OnboardingSearchSuggestionsPixelReporting, OnboardingSiteSuggestionsPixelReporting {

    private unowned let onboardingStateProvider: ContextualOnboardingStateUpdater
    private let fire: (PixelKitEventV2, PixelKit.Frequency) -> Void
    private let userDefaults: UserDefaults

    init(onboardingStateProvider: ContextualOnboardingStateUpdater = Application.appDelegate.onboardingStateMachine,
         userDefaults: UserDefaults = UserDefaults.standard,
         fireAction: @escaping (PixelKitEventV2, PixelKit.Frequency) -> Void = { event, frequency in PixelKit.fire(event, frequency: frequency) }) {
        self.onboardingStateProvider = onboardingStateProvider
        self.fire = fireAction
        self.userDefaults = userDefaults
    }

    func trackSiteSuggetionOptionTapped() {
        fire(ContextualOnboardingPixel.siteSuggetionOptionTapped, .uniqueByName)
    }

    func trackSearchSuggetionOptionTapped() {
        fire(ContextualOnboardingPixel.searchSuggetionOptionTapped, .uniqueByName)
    }
}

extension OnboardingPixelReporter: OnboardingAddressBarReporting {
    func trackPrivacyDashboardOpened() {
        if onboardingStateProvider.state != .onboardingCompleted {
            fire(ContextualOnboardingPixel.onboardingPrivacyDashboardOpened, .uniqueByName)
        }
    }

    func trackAddressBarTypedIn() {
        if onboardingStateProvider.state == .showTryASearch {
            fire(ContextualOnboardingPixel.onboardingSearchCustom, .uniqueByName)
        }
        if onboardingStateProvider.state == .showTryASite {
            fire(ContextualOnboardingPixel.onboardingVisitSiteCustom, .uniqueByName)
        }
    }

    func trackSiteVisited() {
        let key = "onboarding.website-visited"
        let siteVisited = userDefaults.bool(forKey: key)
        if siteVisited {
            fire(ContextualOnboardingPixel.secondSiteVisited, .uniqueByName)
        } else {
            userDefaults.set(true, forKey: key)
        }
    }
}

extension OnboardingPixelReporter: OnboardingFireReporting {
    func trackFireButtonPressed() {
        if onboardingStateProvider.state != .onboardingCompleted {
            fire(ContextualOnboardingPixel.onboardingFireButtonPressed, .uniqueByName)
        }
    }
}

extension OnboardingPixelReporter: OnboardingDialogsReporting {
    func trackLastDialogShown() {
        fire(ContextualOnboardingPixel.onboardingFinished, .uniqueByName)
    }

    func trackFireButtonSkipped() {
        fire(ContextualOnboardingPixel.onboardingFireButtonPromptSkipPressed, .uniqueByName)
    }

    func trackFireButtonTryIt() {
        fire(ContextualOnboardingPixel.onboardingFireButtonTryItPressed, .uniqueByName)
    }
}
