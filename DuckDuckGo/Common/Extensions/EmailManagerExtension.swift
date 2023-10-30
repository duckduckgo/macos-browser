//
//  EmailManagerExtension.swift
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
import BrowserServicesKit
import PixelKit

extension EmailManager {

    @UserDefaultsWrapper(key: .emailKeychainMigration, defaultValue: false)
    private static var emailKeychainMigrationDone: Bool

    convenience init() {
        defer {
            Self.emailKeychainMigrationDone = true
        }
        self.init(storage: EmailKeychainManager(needsMigration: !Self.emailKeychainMigrationDone))
    }

    var emailPixelParameters: [String: String] {
        var pixelParameters: [String: String] = [:]

        if let cohort = self.cohort {
            pixelParameters[PixelKit.Parameters.emailCohort] = cohort
        }

        pixelParameters[PixelKit.Parameters.emailLastUsed] = self.lastUseDate

        return pixelParameters
    }

}
