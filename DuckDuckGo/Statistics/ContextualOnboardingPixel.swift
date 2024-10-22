//
//  ContextualOnboardingPixel.swift
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
import PixelKit

/**
 * This enum keeps pixels related to the Contextual  Onboarding.
 *
 * > Related links:
 * [Privacy Triage]()
 * [Detailed Pixels description](https://app.asana.com/0/1201621853593513/1208114308034584/f)
 */
enum ContextualOnboardingPixel: PixelKitEventV2 {
    /**
     * Event Trigger: User types into the address bar when the search suggestions dialog is shown during the contextual onboarding
     *
     * Anomaly Investigation:

     */
    case onboardingSearchCustom

    /**
     * Event Trigger: User types into the address bar when the site suggestions dialog  is shown during the contextual onboarding
     *
     * Anomaly Investigation:

     */
    case onboardingVisitSiteCustom

    /**
     * Event Trigger: The “skip” button on the Fire Button dialog during the contextual onboarding
     *
     * Anomaly Investigation:

     */
    case onboardingFireButtonPromptSkipPressed

    /**
     * Event Trigger: The final onboarding dialog is displayed during the contextual onboarding
     *
     * Anomaly Investigation:

     */
    case onboardingFinished

    /**
     * Event Trigger: The Fire button is clicked from the Fire Button dialog during the contextual onboarding
     *
     * Anomaly Investigation:

     */
    case onboardingFireButtonPressed

    /**
     * Event Trigger: The privacy dashboard is opened from the Trackers dialog during the contextual onboarding
     *
     * Anomaly Investigation:

     */
    case onboardingPrivacyDashboardOpened

    /**
     * Event Trigger:
     *
     * Anomaly Investigation:

     */
    case secondSiteVisited

    var name: String {
        switch self {
        case .onboardingSearchCustom:
            return "m_mac_onboarding_search_custom"
        case .onboardingVisitSiteCustom:
            return "m_mac_onboarding_visit_site_custom"
        case .onboardingFireButtonPromptSkipPressed:
            return "m_mac_onboarding_fire_button_prompt_skip_pressed"
        case .onboardingFinished:
            return "m_mac_onboarding_finished"
        case .onboardingFireButtonPressed:
            return "m_mac_onboarding_fire_button_pressed"
        case .onboardingPrivacyDashboardOpened:
            return "m_mac_onboarding_privacy_dashboard_opened"
        case .secondSiteVisited:
            return "m_mac_second_site_visit_u"
        }
    }

    var parameters: [String: String]? {
        nil
    }

    var error: (any Error)? {
        nil
    }
}
