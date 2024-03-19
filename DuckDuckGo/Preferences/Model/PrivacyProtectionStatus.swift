//
//  PrivacyProtectionStatus.swift
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

import SwiftUI
import Combine
import BrowserServicesKit

final class PrivacyProtectionStatus: ObservableObject {

    static func status(for preferencePane: PreferencePaneIdentifier) -> PrivacyProtectionStatus {
        switch preferencePane {
        case .defaultBrowser:
            return PrivacyProtectionStatus(statusPublisher: DefaultBrowserPreferences.shared.$isDefault) { isDefault in
                isDefault ? .on : .off
            }
        case .privateSearch:
            return PrivacyProtectionStatus(statusIndicator: .on)
        case .webTrackingProtection:
            return PrivacyProtectionStatus(statusIndicator: .on)
        case .cookiePopupProtection:
            return PrivacyProtectionStatus(statusPublisher: CookiePopupProtectionPreferences.shared.$isAutoconsentEnabled) { isAutoconsentEnabled in
                isAutoconsentEnabled ? .on : .off
            }
        case .emailProtection:
            let publisher = Publishers.Merge(
                NotificationCenter.default.publisher(for: .emailDidSignIn),
                NotificationCenter.default.publisher(for: .emailDidSignOut)
            )
            return PrivacyProtectionStatus(statusPublisher: publisher, initialValue: EmailManager().isSignedIn ? .on : .off) { _ in
                EmailManager().isSignedIn ? .on : .off
            }
        default:
            return PrivacyProtectionStatus()
        }
    }

    var statusSubscription: AnyCancellable?
    @Published var status: Preferences.StatusIndicator?

    // Initializer for observable properties
    init<T: Publisher>(statusPublisher: T,
                       initialValue: Preferences.StatusIndicator? = nil,
                       transform: @escaping (T.Output) -> Preferences.StatusIndicator?) where T.Failure == Never {
        self.status = initialValue

        statusSubscription = statusPublisher
            .map(transform)
            .sink { [weak self] newStatus in
                self?.status = newStatus
            }
    }

    // Initializer for items without a status
    init() {
        self.status = nil
    }

    // Initializer for items with static status
    init(statusIndicator: Preferences.StatusIndicator) {
        self.status = statusIndicator
    }
}
