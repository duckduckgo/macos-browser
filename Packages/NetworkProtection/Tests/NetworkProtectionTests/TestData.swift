//
//  TestData.swift
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

final class TestData {

    static var mockServers: Data {
        return loadData(named: "servers.json")!
    }

    private static func loadData(named name: String) -> Data? {
        guard let resourceUrl = Bundle.module.resourceURL else { return nil }

        let url = resourceUrl.appendingPathComponent(name)

        let finalURL: URL
        if FileManager.default.fileExists(atPath: url.path) {
            finalURL = url
        } else {
            // Workaround for resource bundle having a different structure when running tests from command line.
            let url = resourceUrl.deletingLastPathComponent().appendingPathComponent(name)

            if FileManager.default.fileExists(atPath: url.path) {
                finalURL = url
            } else {
                return nil
            }
        }

        guard let data = try? Data(contentsOf: finalURL, options: [.mappedIfSafe]) else { return nil }
        return data
    }

}
