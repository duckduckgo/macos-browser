//
//  AppGroupHelper.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import os.log

/// Generic helper to retrieve access Network Protection App group resources.
///
public final class AppGroupHelper {
    public static let shared = AppGroupHelper()

    let appGroup: String

    /// Apps that want to use this class need set the app group in their Info.plist.
    ///
    /// - Parameters:
    ///     - infoPlistKey: the key in the Info.plist file that will contain Network Protection's app group.
    ///         If none is specified the default value used is `NETP_APP_GROUP`.
    ///
    public init(infoPlistKey: String = "NETP_APP_GROUP") {
        guard let appGroup = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String else {   
            fatalError("Make sure key \(infoPlistKey) is defined in info.plist")
        }

        self.appGroup = appGroup
    }

    /// The app group's shared UserDefaults
    ///
    public var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }
}
