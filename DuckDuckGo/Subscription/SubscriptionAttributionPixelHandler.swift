//
//  SubscriptionAttributionPixelHandler.swift
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

protocol SubscriptionAttributionPixelHandler {
    func fireSuccessfulSubscriptionAttributionPixel()
}

// MARK: - SubscriptionAttributionPixelHandler

final class PrivacyProSubscriptionAttributionPixelHandler: SubscriptionAttributionPixelHandler {
    private let decoratedAttributionPixelHandler: AttributionPixelHandler
    private let originStore: SubscriptionOriginStorage

    init(attributionPixelHandler: AttributionPixelHandler, originStore: SubscriptionOriginStorage) {
        decoratedAttributionPixelHandler = attributionPixelHandler
        self.originStore = originStore
    }

    func fireSuccessfulSubscriptionAttributionPixel() {
        decoratedAttributionPixelHandler.fireAttributionPixel(
            event: PrivacyProPixel.privacyProSuccessfulSubscriptionAttribution,
            frequency: .standard,
            parameters: nil
        )
        originStore.origin = nil
    }

}

// MARK: -

extension PrivacyProSubscriptionAttributionPixelHandler {

    static let `default`: PrivacyProSubscriptionAttributionPixelHandler = {
        let originStore = SubscriptionOriginStore(userDefaults: UserDefaults.subs)
        return PrivacyProSubscriptionAttributionPixelHandler(
            attributionPixelHandler: GenericAttributionPixelHandler(originProvider: originStore),
            originStore: originStore
        )
    }()

}

// MARK: SubscriptionOriginStore + AttributionOriginProvider

extension SubscriptionOriginStore: AttributionOriginProvider {}
