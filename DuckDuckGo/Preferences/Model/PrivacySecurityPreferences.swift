//
//  PrivacySecurityPreferences.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import Combine

final class PrivacySecurityPreferences {
    static let shared = PrivacySecurityPreferences()

    private init() {}

    @UserDefaultsWrapper(key: .loginDetectionEnabled, defaultValue: true)
    var loginDetectionEnabled: Bool

    @UserDefaultsWrapper(key: .gpcEnabled, defaultValue: true)
    var gpcEnabled: Bool {
        didSet {
            gpcEnabledUpdatesSubject.send(gpcEnabled)
        }
    }

    private let gpcEnabledUpdatesSubject = PassthroughSubject<Bool, Never>()
    var gpcEnabledUpdatesPublisher: AnyPublisher<Bool, Never> {
        gpcEnabledUpdatesSubject.eraseToAnyPublisher()
    }

}

extension PrivacySecurityPreferences: PreferenceSection {
    
    var displayName: String {
        return UserText.privacyAndSecurity
    }

    var preferenceIcon: NSImage {
        return NSImage(named: "Privacy")!
    }

}
