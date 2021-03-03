//
//  WebExtension.swift
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

class WebExtension {

    // swiftlint:disable identifier_name
    struct Manifest: Decodable {
        let name: String
        let content_scripts: [ContentScripts]?

        struct ContentScripts: Decodable {
            let js: [String]
        }
    }
    // swiftlint:enable identifier_name

    let manifest: Manifest

    init?(path: URL) {
        let manifestUrl = path.appendingPathComponent("manifest.json")
        guard let jsonData = try? Data(contentsOf: manifestUrl) else {
            return nil
        }

        let decoder = JSONDecoder()
        guard let manifest = try? decoder.decode(Manifest.self, from: jsonData) else {
            return nil
        }

        self.manifest = manifest

        //todo icon
        //js
        //try import js to webviews
        //extension management view
    }

}
