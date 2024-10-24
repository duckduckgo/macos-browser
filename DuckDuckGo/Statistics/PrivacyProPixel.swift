//
//  PrivacyProPixel.swift
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
import Subscription
import PixelKit

// swiftlint:disable private_over_fileprivate
#if APPSTORE
fileprivate let appDistribution = "store"
#else
fileprivate let appDistribution = "direct"
#endif
// swiftlint:enable private_over_fileprivate

enum PrivacyProPixel: PixelKitEventV2 {
    // Subscription
    case privacyProSubscriptionActive
    case privacyProOfferScreenImpression
    case privacyProPurchaseAttempt
    case privacyProPurchaseFailure
    case privacyProPurchaseFailureStoreError
    case privacyProPurchaseFailureBackendError
    case privacyProPurchaseFailureAccountNotCreated
    case privacyProPurchaseSuccess
    case privacyProRestorePurchaseOfferPageEntry
    case privacyProRestorePurchaseClick
    case privacyProRestorePurchaseSettingsMenuEntry
    case privacyProRestorePurchaseEmailStart
    case privacyProRestorePurchaseStoreStart
    case privacyProRestorePurchaseEmailSuccess
    case privacyProRestorePurchaseStoreSuccess
    case privacyProRestorePurchaseStoreFailureNotFound
    case privacyProRestorePurchaseStoreFailureOther
    case privacyProRestoreAfterPurchaseAttempt
    case privacyProSubscriptionActivated
    case privacyProWelcomeAddDevice
    case privacyProAddDeviceEnterEmail
    case privacyProWelcomeVPN
    case privacyProWelcomePersonalInformationRemoval
    case privacyProWelcomeIdentityRestoration
    case privacyProSubscriptionSettings
    case privacyProVPNSettings
    case privacyProPersonalInformationRemovalSettings
    case privacyProIdentityRestorationSettings
    case privacyProSubscriptionManagementEmail
    case privacyProSubscriptionManagementPlanBilling
    case privacyProSubscriptionManagementRemoval
    case privacyProPurchaseStripeSuccess
    case privacyProSuccessfulSubscriptionAttribution
    // Web pixels
    case privacyProOfferMonthlyPriceClick
    case privacyProOfferYearlyPriceClick
    case privacyProAddEmailSuccess
    case privacyProWelcomeFAQClick

    var name: String {
        switch self {
        case .privacyProSubscriptionActive: return "m_mac_\(appDistribution)_privacy-pro_app_subscription_active"
        case .privacyProOfferScreenImpression: return "m_mac_\(appDistribution)_privacy-pro_offer_screen_impression"
        case .privacyProPurchaseAttempt: return "m_mac_\(appDistribution)_privacy-pro_terms-conditions_subscribe_click"
        case .privacyProPurchaseFailure: return "m_mac_\(appDistribution)_privacy-pro_app_subscription-purchase_failure_other"
        case .privacyProPurchaseFailureStoreError: return "m_mac_\(appDistribution)_privacy-pro_app_subscription-purchase_failure_store"
        case .privacyProPurchaseFailureBackendError: return "m_mac_\(appDistribution)_privacy-pro_app_subscription-purchase_failure_backend"
        case .privacyProPurchaseFailureAccountNotCreated: return "m_mac_\(appDistribution)_privacy-pro_app_subscription-purchase_failure_account-creation"
        case .privacyProPurchaseSuccess: return "m_mac_\(appDistribution)_privacy-pro_app_subscription-purchase_success"
        case .privacyProRestorePurchaseOfferPageEntry: return "m_mac_\(appDistribution)_privacy-pro_offer_restore-purchase_click"
        case .privacyProRestorePurchaseClick: return "m_mac_\(appDistribution)_privacy-pro_settings_restore-purchase_click"
        case .privacyProRestorePurchaseSettingsMenuEntry: return "m_mac_\(appDistribution)_privacy-pro_settings_restore-purchase_click"
        case .privacyProRestorePurchaseEmailStart: return "m_mac_\(appDistribution)_privacy-pro_activate-subscription_enter-email_click"
        case .privacyProRestorePurchaseStoreStart: return "m_mac_\(appDistribution)_privacy-pro_activate-subscription_restore-purchase_click"
        case .privacyProRestorePurchaseEmailSuccess: return "m_mac_\(appDistribution)_privacy-pro_app_subscription-restore-using-email_success"
        case .privacyProRestorePurchaseStoreSuccess: return "m_mac_\(appDistribution)_privacy-pro_app_subscription-restore-using-store_success"
        case .privacyProRestorePurchaseStoreFailureNotFound: return "m_mac_\(appDistribution)_privacy-pro_subscription-restore-using-store_failure_not-found"
        case .privacyProRestorePurchaseStoreFailureOther: return "m_mac_\(appDistribution)_privacy-pro_app_subscription-restore-using-store_failure_other"
        case .privacyProRestoreAfterPurchaseAttempt: return "m_mac_\(appDistribution)_privacy-pro_app_subscription-restore-after-purchase-attempt_success"
        case .privacyProSubscriptionActivated: return "m_mac_\(appDistribution)_privacy-pro_app_subscription_activated_u"
        case .privacyProWelcomeAddDevice: return "m_mac_\(appDistribution)_privacy-pro_welcome_add-device_click_u"
        case .privacyProAddDeviceEnterEmail: return "m_mac_\(appDistribution)_privacy-pro_add-device_enter-email_click"
        case .privacyProWelcomeVPN: return "m_mac_\(appDistribution)_privacy-pro_welcome_vpn_click_u"
        case .privacyProWelcomePersonalInformationRemoval: return "m_mac_\(appDistribution)_privacy-pro_welcome_personal-information-removal_click_u"
        case .privacyProWelcomeIdentityRestoration: return "m_mac_\(appDistribution)_privacy-pro_welcome_identity-theft-restoration_click_u"
        case .privacyProSubscriptionSettings: return "m_mac_\(appDistribution)_privacy-pro_settings_screen_impression"
        case .privacyProVPNSettings: return "m_mac_\(appDistribution)_privacy-pro_settings_vpn_click"
        case .privacyProPersonalInformationRemovalSettings: return "m_mac_\(appDistribution)_privacy-pro_settings_personal-information-removal_click"
        case .privacyProIdentityRestorationSettings: return "m_mac_\(appDistribution)_privacy-pro_settings_identity-theft-restoration_click"
        case .privacyProSubscriptionManagementEmail: return "m_mac_\(appDistribution)_privacy-pro_manage-email_edit_click"
        case .privacyProSubscriptionManagementPlanBilling: return "m_mac_\(appDistribution)_privacy-pro_settings_change-plan-or-billing_click"
        case .privacyProSubscriptionManagementRemoval: return "m_mac_\(appDistribution)_privacy-pro_settings_remove-from-device_click"
        case .privacyProPurchaseStripeSuccess: return "m_mac_\(appDistribution)_privacy-pro_app_subscription-purchase_stripe_success"
        case .privacyProSuccessfulSubscriptionAttribution: return "m_mac_\(appDistribution)_subscribe"
            // Web
        case .privacyProOfferMonthlyPriceClick: return "m_mac_\(appDistribution)_privacy-pro_offer_monthly-price_click"
        case .privacyProOfferYearlyPriceClick: return "m_mac_\(appDistribution)_privacy-pro_offer_yearly-price_click"
        case .privacyProAddEmailSuccess: return "m_mac_\(appDistribution)_privacy-pro_app_add-email_success_u"
        case .privacyProWelcomeFAQClick: return "m_mac_\(appDistribution)_privacy-pro_welcome_faq_click_u"
        }
    }

    var error: (any Error)? {
        return nil
    }

    var parameters: [String: String]? {
        return nil
    }
}

enum PrivacyProErrorPixel: PixelKitEventV2 {

    case privacyProKeychainAccessError(accessType: AccountKeychainAccessType, accessError: AccountKeychainAccessError)

    var name: String {
        switch self {
        case .privacyProKeychainAccessError: return "m_mac_privacy-pro_keychain_access_error"
        }
    }

    var parameters: [String: String]? {
        switch self {
        case .privacyProKeychainAccessError(let accessType, let accessError):
            return [
                "type": accessType.rawValue,
                "error": accessError.errorDescription
            ]
        }
    }

    var error: (any Error)? {
        return nil
    }

}
