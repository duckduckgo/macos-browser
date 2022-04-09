//
//  SafariVersionReader.swift
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

struct SafariVersionReader {

    static let safariPlistPath = "/Applications/Safari.app/Contents/Info.plist"

    static func getVersion() -> String? {
        guard
            let plist = NSDictionary(contentsOfFile: Self.safariPlistPath),
            let versionNumber = plist.object(forKey: Bundle.Keys.versionNumber) as? String else {
            assertionFailure("Reading the version of Safari failed")
            return nil
        }

        return versionNumber
    }

}
