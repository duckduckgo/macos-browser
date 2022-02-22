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

struct PrivacySecurityPreferences {

    @UserDefaultsWrapper(key: .loginDetectionEnabled, defaultValue: true)
    public var loginDetectionEnabled: Bool
    
    @UserDefaultsWrapper(key: .gpcEnabled, defaultValue: true)
    public var gpcEnabled: Bool {
        didSet {
            DefaultScriptSourceProvider.shared.reload(knownChanges: [:])
            GPCRequestFactory.shared.reloadGPCSetting()
        }
    }
    
    // This setting is an optional boolean as it has three states:
    // - nil: User has not chosen a setting
    // - true: Enabled by the user
    // - false: Disabled by the user
    @UserDefaultsWrapper(key: .autoconsentEnabled, defaultValue: nil)
    public var autoconsentEnabled: Bool?
}

extension PrivacySecurityPreferences: PreferenceSection {
    
    var displayName: String {
        return UserText.privacyAndSecurity
    }

    var preferenceIcon: NSImage {
        return NSImage(named: "Privacy")!
    }

}
