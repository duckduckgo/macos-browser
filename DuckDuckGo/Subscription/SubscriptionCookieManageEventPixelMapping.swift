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

    case missingTokenOnSignIn
    case cookieRefreshedWithAccessToken
    case cookieRefreshedWithEmptyValue
    case failedToSetSubscriptionCookie

    var name: String {
        switch self {
        case .missingTokenOnSignIn:
            return "m_mac_privacy-pro_subscription-cookie-missing_token_on_sign_in"
        case .cookieRefreshedWithAccessToken:
            return "m_mac_privacy-pro_subscription-cookie-refreshed_with_access_token"
        case .cookieRefreshedWithEmptyValue:
            return "m_mac_privacy-pro_subscription-cookie-refreshed_with_empty_value"
        case .failedToSetSubscriptionCookie:
            return "m_mac_privacy-pro_subscription-cookie-failed_to_set_subscription_cookie"
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
                    return .missingTokenOnSignIn
                case .subscriptionCookieRefreshedWithAccessToken:
                    return .cookieRefreshedWithAccessToken
                case .subscriptionCookieRefreshedWithEmptyValue:
                    return .cookieRefreshedWithEmptyValue
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
