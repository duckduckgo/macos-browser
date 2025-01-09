//
//  SubscriptionRedirectManager.swift
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
import BrowserServicesKit

protocol SubscriptionRedirectManager: AnyObject {
    func redirectURL(for url: URL) -> URL?
}

final class PrivacyProSubscriptionRedirectManager: SubscriptionRedirectManager {

    private let subscriptionEnvironment: SubscriptionEnvironment
    private let canPurchase: () -> Bool
    private let baseURL: URL

    init(subscriptionEnvironment: SubscriptionEnvironment,
         baseURL: URL,
         canPurchase: @escaping () -> Bool) {
        self.subscriptionEnvironment = subscriptionEnvironment
        self.canPurchase = canPurchase
        self.baseURL = baseURL
    }

    func redirectURL(for url: URL) -> URL? {
        guard url.isPart(ofDomain: "duckduckgo.com") else { return nil }

        if url.pathComponents == URL.privacyPro.pathComponents {
            let shouldHidePrivacyProDueToNoProducts = subscriptionEnvironment.purchasePlatform == .appStore && canPurchase() == false
            let isPurchasePageRedirectActive = !shouldHidePrivacyProDueToNoProducts
            // Redirect the `/pro` URL to `/subscriptions` URL. If there are any query items in the original URL it appends to the `/subscriptions` URL.
            return isPurchasePageRedirectActive ? baseURL.addingQueryItems(from: url) : nil
        }

        return nil
    }
}

fileprivate extension URL {

    func addingQueryItems(from url: URL) -> URL {
        // If the origin value is of type "do+something" appending the percentEncodedQueryItem crashes the browser as + is replaced by a space.
        // Perform encoding on the value to avoid the crash.
        guard let queryItems = url.getQueryItems()?
            .compactMap({ queryItem -> URLQueryItem? in
                guard let value = queryItem.value else { return nil }
                let encodedValue = value.percentEncoded(withAllowedCharacters: .urlQueryParameterAllowed)
                return URLQueryItem(name: queryItem.name, value: encodedValue)
            })
        else { return self }

        return self.appending(percentEncodedQueryItems: queryItems)
    }

}
