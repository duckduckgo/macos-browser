//
//  PersistentViewSettings.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

/// Describes app interface settings that are changed outside of the core Settings interface, but need to be persisted between launches.
final class PersistentAppInterfaceSettings {

    static let shared = PersistentAppInterfaceSettings()

    static let showBookmarksBarSettingChanged = NSNotification.Name("ShowBookmarksBarSettingChanged")

    @UserDefaultsWrapper(key: .showBookmarksBar, defaultValue: false)
    var showBookmarksBar: Bool {
        didSet {
            NotificationCenter.default.post(name: PersistentAppInterfaceSettings.showBookmarksBarSettingChanged, object: nil)
        }
    }

}
