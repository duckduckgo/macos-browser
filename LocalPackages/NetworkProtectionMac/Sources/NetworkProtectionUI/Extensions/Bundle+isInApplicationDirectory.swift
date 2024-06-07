//
//  Bundle+isInApplicationDirectory.swift
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

import Foundation

extension Bundle {
    var isInApplicationDirectory: Bool {
        guard let appPath = resourceURL?.deletingLastPathComponent() else { return false }
        let dirPaths = NSSearchPathForDirectoriesInDomains(.applicationDirectory, .localDomainMask, true)
        for path in dirPaths {
            let filePath: URL
            if #available(macOS 13.0, *) {
                filePath = URL(filePath: path)
            } else {
                filePath = URL(fileURLWithPath: path)
            }
            if appPath.absoluteString.hasPrefix(filePath.absoluteString) {
                return true
            }
        }
        return false
    }
}
