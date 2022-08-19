//
//  DarkSitesConfigManager.swift
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
import OSLog

struct DarkSitesConfigManager {
    private let log = OSLog(subsystem: "com.duckduckgo.instrumentation", category: "DarkModeInstrumentation")

    // ETag: W/"fb87499571281a90fd8bcef3d0e0e3a70334480df5ee452db4fc51e6c4f3d43b"

    private let darkSites: [String]

    init() {
        self.darkSites = DarkSitesConfigManager.loadDarkSitesConfig()
    }

    #warning("Test code, needs to be improved")
    func isURLInList(_ url: URL) -> Bool {
        
        let logName = StaticString(stringLiteral: "Dark List Scan")
        let listScanID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: logName, signpostID: listScanID)
        
        defer {
            os_signpost(.end, log: log, name: logName, signpostID: listScanID)
        }
        
        print("Checking if \(url) is in darklist")
        guard let host = url.host else { return false }
        let value = "\(host)\(url.path)"
        
        let result = darkSites.filter { value.contains($0) }
        return result.count > 0
    }
    
    private static func loadDarkSitesConfig() -> [String] {
        let url = Bundle.main.url(
            forResource: "dark-sites",
            withExtension: "config"
        )
        
        guard let data = try? String(contentsOf: url!)
            .components(separatedBy: "\n") else {
            
            assertionFailure("Failed to load text file")
            return []
        }

        return data
    }

}
