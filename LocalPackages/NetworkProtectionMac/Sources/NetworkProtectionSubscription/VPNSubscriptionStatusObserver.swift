//
//  VPNSubscriptionStatusObserver.swift
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

import Combine
import Foundation
import Subscription

public final class VPNSubscriptionStatusObserver {

    public var showSubscriptionExpired: AnyPublisher<Bool, Never> {
        publisher.eraseToAnyPublisher()
    }

    private let publisher = CurrentValueSubject<Bool, Never>(false)
    private var cancellables = Set<AnyCancellable>()

    public init(notificationCenter: NotificationCenter = .default) {
        subscribeToEntitlementChangeNotifications(through: notificationCenter)
    }

    private func subscribeToEntitlementChangeNotifications(through notificationCenter: NotificationCenter) {
        notificationCenter.publisher(for: .entitlementsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let entitlements = notification.userInfo?[UserDefaultsCacheKey.subscriptionEntitlements] as? [Entitlement] else {
                    return
                }

                publisher.value = !entitlements.contains { entitlement in
                    entitlement.product == .networkProtection
                }
            }
            .store(in: &cancellables)
    }
}
