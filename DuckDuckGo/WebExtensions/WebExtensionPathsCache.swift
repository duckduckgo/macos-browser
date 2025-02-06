//
//  WebExtensionPathsCache.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

@available(macOS 14.4, *)
protocol WebExtensionPathsCaching: AnyObject {

    var cache: [String] { get }
    func add(_ url: String)
    func remove(_ url: String)

}

@available(macOS 14.4, *)
final class WebExtensionPathsCache: WebExtensionPathsCaching {

    @UserDefaultsWrapper(key: .webExtensionPathsCache, defaultValue: [])
    var cache: [String]

    func add(_ url: String) {
        guard !cache.contains(url) else {
            assertionFailure("Already cached: \(url)")
            return
        }

        cache.append(url)
    }

    func remove(_ url: String) {
        guard cache.contains(url) else {
            assertionFailure("Not cached: \(url)")
            return
        }

        cache.removeAll(where: { $0 == url })
    }

}
