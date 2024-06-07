//
//  FirefoxCompatibilityPreferences.swift
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

import Common
import Foundation

struct FirefoxCompatibilityPreferences {

    enum Constants {
        static let firefoxCompatibilityPreferencesFileName = "compatibility.ini"
    }

    let lastVersion: String?

    private static let lastVersionRegex = regex("^\\s*LastVersion\\s*=\\s*(\\S+)\\s*$")

    init(from data: Data) {
        var lastVersion: String?
        data.utf8String()?.enumerateLines(invoking: { line, stop in
            guard let match = Self.lastVersionRegex.firstMatch(in: line, options: [], range: line.fullRange),
                  let range = Range(match.range(at: 1), in: line) else { return }
            lastVersion = String(line[range])
            stop = true
        })

        self.lastVersion = lastVersion
    }

    init(profileURL: URL, fileStore: FileStore = FileManager.default) throws {
        guard let preferencesData = fileStore.loadData(at: profileURL.appendingPathComponent(Constants.firefoxCompatibilityPreferencesFileName)) else {
            throw CocoaError(.fileReadUnknown)
        }
        self.init(from: preferencesData)
    }

}
