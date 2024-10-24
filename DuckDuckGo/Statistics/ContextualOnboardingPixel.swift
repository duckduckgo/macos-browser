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
     * It is triggered in  OnboardingSearchSuggestionsViewModel when one of the search suggestion button in the list is pressed (listItemPressed) in the contextual onboarding
     * Check code in that area and in OnboardingPixelReporter to check it behaves as expected
     */
    case siteSuggetionOptionTapped

    /**
     * Event Trigger: User types into the address bar when the search suggestions dialog is shown during the contextual onboarding
     *
     * Anomaly Investigation:
     * It is triggered in  OnboardingSiteSuggestionsViewModel when one of the site suggestion button in the list is pressed (listItemPressed) in the contextual onboarding
     * Check code in that area and in OnboardingPixelReporter to check it behaves as expected
     */
    case searchSuggetionOptionTapped

    /**
     * Event Trigger: User types into the address bar when the search suggestions dialog is shown during the contextual onboarding
     *
     * Anomaly Investigation:
     * It is triggered in  AddressBarTextField on  controlTextDidChange.
     * The OnboardingPixelReporter then sends a pixel if this happens when try a search onboarding dialog is on
     * Check code in that area and in OnboardingPixelReporter to check it behaves as expected
     */
    case onboardingSearchCustom

    /**
     * Event Trigger: User types into the address bar when the site suggestions dialog  is shown during the contextual onboarding
     *
     * Anomaly Investigation:
     * It is triggered in  AddressBarTextField on  controlTextDidChange.
     * The OnboardingPixelReporter then sends a pixel if this happens when try a site onboarding dialog is on
     * Check code in that area and in OnboardingPixelReporter to check it behaves as expected
     */
    case onboardingVisitSiteCustom

    /**
     * Event Trigger: The “skip” button on the Fire Button dialog during the contextual onboarding
     *
     * Anomaly Investigation:
     * It is triggered on skip in the OnboardingFireButtonDialogViewModel.
     * Check code in that area  to check it behaves as expected
     */
    case onboardingFireButtonPromptSkipPressed

    /**
     * Event Trigger: The “skip” button on the Fire Button dialog during the contextual onboarding
     *
     * Anomaly Investigation:
     * It is triggered on tryFireButton in the OnboardingFireButtonDialogViewModel.
     * Check code in that area  to check it behaves as expected
     */
    case onboardingFireButtonTryItPressed

    /**
     * Event Trigger: The final onboarding dialog is displayed during the contextual onboarding
     *
     * Anomaly Investigation:
     * It is triggered on when HighFive dialog is returned DefaultContextualDaxDialogViewFactory
     * and on skip in the OnboardingFireButtonDialogViewModel.
     * Check code in that area  to check it behaves as expected
     */
    case onboardingFinished

    /**
     * Event Trigger: The Fire button is clicked from the Fire Button dialog during the contextual onboarding
     *
     * Anomaly Investigation:
     * It is triggered on fireButtonAction on MainMenuActions
     * the OnboardingPixelProvider sends it only if the state non e' onboardingComleted
     * Check code in that area  to check it behaves as expected
     */
    case onboardingFireButtonPressed

    /**
     * Event Trigger: The privacy dashboard is opened from the Trackers dialog during the contextual onboarding
     *
     * Anomaly Investigation:
     * It is triggered on privacyEntryPointButtonAction on AddressBarButtonViewController
     * the OnboardingPixelProvider sends it only if the state non e' onboardingComleted
     * Check code in that area  to check it behaves as expected
     */
    case onboardingPrivacyDashboardOpened

    /**
     * Event Trigger:
     * It is triggered on didFinishLoading on Tab only if it's not a search
     * the OnboardingPixelProvider sends it only the second time
     * Check code in that area  to check it behaves as expected
     */
    case secondSiteVisited

    var name: String {
        switch self {
        case .onboardingSearchCustom:
            return "m_mac_onboarding_search_custom_u"
        case .onboardingVisitSiteCustom:
            return "m_mac_onboarding_visit_site_custom_u"
        case .onboardingFireButtonPromptSkipPressed:
            return "m_mac_onboarding_fire_button_prompt_skip_pressed_u"
        case .onboardingFinished:
            return "m_mac_onboarding_finished_u"
        case .onboardingFireButtonPressed:
            return "m_mac_onboarding_fire_button_pressed_u"
        case .onboardingPrivacyDashboardOpened:
            return "m_mac_onboarding_privacy_dashboard_opened_u"
        case .secondSiteVisited:
            return "m_mac_second_site_visit_u"
        case .searchSuggetionOptionTapped:
            return "m_mac_onboarding_search_option_tapped_u"
        case .siteSuggetionOptionTapped:
            return "m_mac_onboarding_visit_site_option_tapped_u"
        case .onboardingFireButtonTryItPressed:
            return "m_mac_onboarding_fire_button_try_it_pressed_u"
        }
    }

    var parameters: [String: String]? {
        nil
    }

    var error: (any Error)? {
        nil
    }
}
