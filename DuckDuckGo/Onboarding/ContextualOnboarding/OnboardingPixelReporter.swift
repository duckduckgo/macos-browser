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

protocol OnboardingAddressBarReporting: AnyObject {
    func trackAddressBarTypedIn()
    func trackPrivacyDashboardOpened()
    func trackSiteVisited()
}

protocol OnboardingDialogsReporting: AnyObject {
    func trackFireButtonSkipped()
    func trackLastDialogShown()
}

protocol OnboardingFireReporting: AnyObject {
    func trackFireButtonPressed()
}

final class OnboardingPixelReporter: OnboardingSearchSuggestionsPixelReporting, OnboardingSiteSuggestionsPixelReporting {
   private  let onboardingStateProvider: ContextualOnboardingStateUpdater

    @UserDefaultsWrapper(key: .websiteVisited, defaultValue: false)
    private var siteVisited: Bool

    init(onboardingStateProvider: ContextualOnboardingStateUpdater = Application.appDelegate.onboardingStateMachine) {
        self.onboardingStateProvider = onboardingStateProvider
    }

    func trackSiteSuggetionOptionTapped() {
    }
    func trackSearchSuggetionOptionTapped() {
    }
}

extension OnboardingPixelReporter: OnboardingAddressBarReporting {
    func trackPrivacyDashboardOpened() {
        if onboardingStateProvider.state != .onboardingCompleted {
            PixelKit.fire(ContextualOnboardingPixel.onboardingPrivacyDashboardOpened)
        }
    }

    func trackAddressBarTypedIn() {
        if onboardingStateProvider.state == .showTryASearch {
            PixelKit.fire(ContextualOnboardingPixel.onboardingSearchCustom)
        }
        if onboardingStateProvider.state == .showTryASite {
            PixelKit.fire(ContextualOnboardingPixel.onboardingVisitSiteCustom)
        }
    }

    func trackSiteVisited() {
        if siteVisited {
            PixelKit.fire(ContextualOnboardingPixel.secondSiteVisited, frequency: .unique)
        } else {
            siteVisited = true
        }
    }
}

extension OnboardingPixelReporter: OnboardingFireReporting {
    func trackFireButtonPressed() {
        if onboardingStateProvider.state != .onboardingCompleted {
            PixelKit.fire(ContextualOnboardingPixel.onboardingFireButtonPressed)
        }
    }
}

extension OnboardingPixelReporter: OnboardingDialogsReporting {
    func trackLastDialogShown() {
        PixelKit.fire(ContextualOnboardingPixel.onboardingFinished)
    }

    func trackFireButtonSkipped() {
        PixelKit.fire(ContextualOnboardingPixel.onboardingFireButtonPromptSkipPressed)
    }
}
