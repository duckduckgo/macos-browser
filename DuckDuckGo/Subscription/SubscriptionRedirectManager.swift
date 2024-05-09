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

    private let originStore: SubscriptionOriginStorage

    init(originStore: SubscriptionOriginStorage = SubscriptionOriginStore(userDefaults: .subs)) {
        self.originStore = originStore
    }

    func redirectURL(for url: URL) -> URL? {
        guard url.isPart(ofDomain: "duckduckgo.com") else { return nil }

        if url.pathComponents == URL.privacyPro.pathComponents {
            let isFeatureAvailable = DefaultSubscriptionFeatureAvailability().isFeatureAvailable
            let shouldHidePrivacyProDueToNoProducts = SubscriptionPurchaseEnvironment.current == .appStore && SubscriptionPurchaseEnvironment.canPurchase == false
            let isPurchasePageRedirectActive = isFeatureAvailable && !shouldHidePrivacyProDueToNoProducts
            // Look for `origin` query parameter and store in the UserDefaults.
            let originQueryItem = url.queryItem(forName: AttributionParameter.origin)
            originStore.origin = originQueryItem?.value
            // If origin query parameter exists forward it to the redirect URL
            return isPurchasePageRedirectActive ? purchasePageRedirectURL(for: url, originQueryItem: originQueryItem) : nil
        }

        return nil
    }

    private func purchasePageRedirectURL(for url: URL, originQueryItem: URLQueryItem?) -> URL {
        originQueryItem
            .flatMap(URL.subscriptionBaseURL.appendingQueryItem(_:)) ?? URL.subscriptionBaseURL
    }

}
