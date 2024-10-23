//
//  SubscriptionCookieManageEventPixelMapping.swift
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
import Common
import PixelKit
import Subscription

enum SubscriptionCookieManagerPixel: PixelKitEventV2 {

    case errorHandlingAccountDidSignInTokenIsMissing
    case errorHandlingAccountDidSignOutCookieIsMissing
    case subscriptionCookieRefreshedWithUpdate
    case subscriptionCookieRefreshedWithDelete
    case failedToSetSubscriptionCookie

    var name: String {
        switch self {
        case .errorHandlingAccountDidSignInTokenIsMissing:
            return "m_mac_privacy-pro_subscription_cookie_error_handling_accountdidsignin_token_is_missing"
        case .errorHandlingAccountDidSignOutCookieIsMissing:
            return "m_mac_privacy-pro_subscription_cookie_error_handling_accountdidsignout_cookie_is_missing"
        case .subscriptionCookieRefreshedWithUpdate:
            return "m_mac_privacy-pro_subscription_cookie_subscription_cookie_refreshed_with_update"
        case .subscriptionCookieRefreshedWithDelete:
            return "m_mac_privacy-pro_subscription_cookie_subscription_cookie_refreshed_with_delete"
        case .failedToSetSubscriptionCookie:
            return "m_mac_privacy-pro_subscription_cookie_failed_to_set_subscription_cookie"
        }
    }

    var error: (any Error)? {
        return nil
    }

    var parameters: [String: String]? {
        return nil
    }
}

public final class SubscriptionCookieManageEventPixelMapping: EventMapping<SubscriptionCookieManagerEvent> {

    public init() {
        super.init { event, _, _, _ in
            let pixel: SubscriptionCookieManagerPixel = {
                switch event {
                case .errorHandlingAccountDidSignInTokenIsMissing: 
                    return .errorHandlingAccountDidSignInTokenIsMissing
                case .errorHandlingAccountDidSignOutCookieIsMissing:
                    return .errorHandlingAccountDidSignOutCookieIsMissing
                case .subscriptionCookieRefreshedWithUpdate:
                    return .subscriptionCookieRefreshedWithUpdate
                case .subscriptionCookieRefreshedWithDelete:
                    return .subscriptionCookieRefreshedWithDelete
                case .failedToSetSubscriptionCookie:
                    return .failedToSetSubscriptionCookie
                }
            }()

            PixelKit.fire(pixel)
        }
    }

    override init(mapping: @escaping EventMapping<SubscriptionCookieManagerEvent>.Mapping) {
        fatalError("Use init()")
    }
}
