//
//  ApplicationVersionReader.swift
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

internal class ApplicationVersionReader {

    static let plistRelativePath = "Contents/Info.plist"

    static func getVersion(of appPath: String) -> String? {
        guard let plist = NSDictionary(contentsOfFile: appPath + "/" + plistRelativePath),
              let versionNumber = plist.object(forKey: Bundle.Keys.versionNumber) as? String else {
            return nil
        }

        return versionNumber
    }

    static func getMajorVersion(of appPath: String) -> Int? {
        if let versionString = Self.getVersion(of: appPath),
           let majorVersion = versionString.components(separatedBy: ".")[safe: 0] {
            return Int(majorVersion)
        } else {
            return nil
        }
    }

}
