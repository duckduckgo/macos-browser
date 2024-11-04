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

protocol SubscriptionAttributionPixelHandler: AnyObject {
    var origin: String? { get set }
    func fireSuccessfulSubscriptionAttributionPixel()
}

// MARK: - SubscriptionAttributionPixelHandler

final class PrivacyProSubscriptionAttributionPixelHandler: SubscriptionAttributionPixelHandler {

    enum Consts {
        static let freemiumOrigin = "funnel_pro_mac_freemium"
    }

    var origin: String?
    private let decoratedAttributionPixelHandler: AttributionPixelHandler

    init(attributionPixelHandler: AttributionPixelHandler = GenericAttributionPixelHandler()) {
        decoratedAttributionPixelHandler = attributionPixelHandler
    }

    func fireSuccessfulSubscriptionAttributionPixel() {
        decoratedAttributionPixelHandler.fireAttributionPixel(
            event: PrivacyProPixel.privacyProSuccessfulSubscriptionAttribution,
            frequency: .standard,
            origin: origin,
            additionalParameters: nil
        )
    }

}
