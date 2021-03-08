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
        let description: String
        let version: String
        let content_scripts: [ContentScripts]?
        let icons: [String: String]?

        struct ContentScripts: Decodable {
            let js: [String]
        }
    }
    // swiftlint:enable identifier_name

    let manifest: Manifest
    let icon: NSImage?
    let contentScript: String?

    init?(path: URL) {

        func manifest(from url: URL) -> Manifest? {
            guard let jsonData = try? Data(contentsOf: url) else {
                return nil
            }

            let decoder = JSONDecoder()
            guard let manifest = try? decoder.decode(Manifest.self, from: jsonData) else {
                return nil
            }

            return manifest
        }

        func icon(from url: URL) -> NSImage? {
            guard let iconData = try? Data(contentsOf: url) else {
                return nil
            }

            return NSImage(data: iconData)
        }

        func javascript(from url: URL) -> String? {
            return try? String(contentsOf: url, encoding: .utf8)
        }

        guard let manifest = manifest(from: path.appendingPathComponent("manifest.json")) else {
            return nil
        }
        self.manifest = manifest

        if let manifestIcons = manifest.icons, let iconPathComponent = Array(manifestIcons.values).last {
            self.icon = icon(from: path.appendingPathComponent(iconPathComponent))
        } else {
            self.icon = NSImage(named: "Web")
        }

        if let contentScripts = manifest.content_scripts {
            let scriptPaths = contentScripts.flatMap { (contentScripts) in
                contentScripts.js
            }
            let joinedScripts = scriptPaths.compactMap { javascript(from: path.appendingPathComponent($0)) }.joined()
            self.contentScript = joinedScripts
        } else {
            self.contentScript = nil
        }

    }

}
