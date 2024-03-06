////
////  SubscriptionPixels.swift
////  Copyright © 2024 DuckDuckGo. All rights reserved.
////
////  Licensed under the Apache License, Version 2.0 (the "License");
////  you may not use this file except in compliance with the License.
////  You may obtain a copy of the License at
////
////  http://www.apache.org/licenses/LICENSE-2.0
////
////  Unless required by applicable law or agreed to in writing, software
////  distributed under the License is distributed on an "AS IS" BASIS,
////  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
////  See the License for the specific language governing permissions and
////  limitations under the License.
////
//
//import Foundation
//import Common
//import BrowserServicesKit
//import PixelKit
//
//public enum SubscriptionPixels {
//    case privacyProSubscriptionActive
//    case privacyProOfferScreenImpression
//    case privacyProPurchaseAttempt
//    case privacyProPurchaseFailure
//    case privacyProPurchaseFailureStoreError
//    case privacyProPurchaseFailureBackendError
//    case privacyProPurchaseFailureAccountNotCreated
//    case privacyProPurchaseSuccess
//    case privacyProRestorePurchaseOfferPageEntry
//    case privacyProRestorePurchaseSettingsMenuEntry
//    case privacyProRestorePurchaseEmailStart
//    case privacyProRestorePurchaseStoreStart
//    case privacyProRestorePurchaseEmailSuccess
//    case privacyProRestorePurchaseStoreSuccess
//    case privacyProRestorePurchaseStoreFailureNotFound
//    case privacyProRestorePurchaseStoreFailureOther
//    case privacyProRestoreAfterPurchaseAttempt
//    case privacyProSubscriptionActivated
//    case privacyProWelcomeAddDevice
//    case privacyProSettingsAddDevice
//    case privacyProAddDeviceEnterEmail
//    case privacyProWelcomeVPN
//    case privacyProWelcomePersonalInformationRemoval
//    case privacyProWelcomeIdentityRestoration
//    case privacyProSubscriptionSettings
//    case privacyProVPNSettings
//    case privacyProPersonalInformationRemovalSettings
//    case privacyProIdentityRestorationSettings
//    case privacyProSubscriptionManagementEmail
//    case privacyProSubscriptionManagementPlanBilling
//    case privacyProSubscriptionManagementRemoval
//}
//
//#if APPSTORE
//fileprivate let pixelPrefix = "m_mac_store_privacy-pro_"
//#else
//fileprivate let pixelPrefix = "m_mac_direct_privacy-pro_"
//#endif
//
//extension SubscriptionPixels: PixelKitEvent {
//
//    public var name: String {
//        switch self {
//        case .privacyProSubscriptionActive: return pixelPrefix + "privacy-pro_app_subscription_active"
//        case .privacyProOfferScreenImpression: return pixelPrefix + "offer_screen_impression"
//        case .privacyProPurchaseAttempt: return pixelPrefix + "terms-conditions_subscribe_click"
//        case .privacyProPurchaseFailure: return pixelPrefix + "app_subscription-purchase_failure_other"
//        case .privacyProPurchaseFailureStoreError: return pixelPrefix + "app_subscription-purchase_failure_store"
//        case .privacyProPurchaseFailureBackendError: return pixelPrefix + "app_subscription-purchase_failure_backend"
//        case .privacyProPurchaseFailureAccountNotCreated: return pixelPrefix + "app_subscription-purchase_failure_account-creation"
//        case .privacyProPurchaseSuccess: return pixelPrefix + "app_subscription-purchase_success"
//        case .privacyProRestorePurchaseOfferPageEntry: return pixelPrefix + "offer_restore-purchase_click"
//        case .privacyProRestorePurchaseSettingsMenuEntry: return pixelPrefix + "settings_restore-purchase_click"
//        case .privacyProRestorePurchaseEmailStart: return pixelPrefix + "activate-subscription_enter-email_click"
//        case .privacyProRestorePurchaseStoreStart: return pixelPrefix + "activate-subscription_restore-purchase_click"
//        case .privacyProRestorePurchaseEmailSuccess: return pixelPrefix + "app_subscription-restore-using-email_success"
//        case .privacyProRestorePurchaseStoreSuccess: return pixelPrefix + "app_subscription-restore-using-store_success"
//        case .privacyProRestorePurchaseStoreFailureNotFound: return pixelPrefix + "subscription-restore-using-store_failure_not-found"
//        case .privacyProRestorePurchaseStoreFailureOther: return pixelPrefix + "app_subscription-restore-using-store_failure_other"
//        case .privacyProRestoreAfterPurchaseAttempt: return pixelPrefix + "app_subscription-restore-after-purchase-attempt_success"
//        case .privacyProSubscriptionActivated: return pixelPrefix + "app_subscription_activated_u"
//        case .privacyProWelcomeAddDevice: return pixelPrefix + "welcome_add-device_click_u"
//        case .privacyProSettingsAddDevice: return pixelPrefix + "settings_add-device_click"
//        case .privacyProAddDeviceEnterEmail: return pixelPrefix + "add-device_enter-email_click"
//        case .privacyProWelcomeVPN: return pixelPrefix + "welcome_vpn_click_u"
//        case .privacyProWelcomePersonalInformationRemoval: return pixelPrefix + "welcome_personal-information-removal_click_u"
//        case .privacyProWelcomeIdentityRestoration: return pixelPrefix + "welcome_identity-theft-restoration_click_u"
//        case .privacyProSubscriptionSettings: return pixelPrefix + "settings_screen_impression"
//        case .privacyProVPNSettings: return pixelPrefix + "settings_vpn_click"
//        case .privacyProPersonalInformationRemovalSettings: return pixelPrefix + "settings_personal-information-removal_click"
//        case .privacyProIdentityRestorationSettings: return pixelPrefix + "settings_identity-theft-restoration_click"
//        case .privacyProSubscriptionManagementEmail: return pixelPrefix + "manage-email_edit_click"
//        case .privacyProSubscriptionManagementPlanBilling: return pixelPrefix + "settings_change-plan-or-billing_click"
//        case .privacyProSubscriptionManagementRemoval: return pixelPrefix + "settings_remove-from-device_click"
//        }
//    }
//
//    public var parameters: [String: String]? {
//        return nil
//    }
//}
//
////public class SubscriptionPixelsHandler: EventMapping<DataBrokerProtectionPixels> {
////
////    public init() {
////        super.init { event, _, _, _ in
////            PixelKit.fire(event)
////        }
////    }
////
////    override init(mapping: @escaping EventMapping<SubscriptionPixels>.Mapping) {
////        fatalError("Use init()")
////    }
////}
