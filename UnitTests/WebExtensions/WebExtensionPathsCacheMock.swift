//
//  WebExtensionPathsCacheMock.swift
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

@testable import DuckDuckGo_Privacy_Browser

@available(macOS 14.4, *)
final class WebExtensionPathsCachingMock: WebExtensionPathsCaching {

    var cache: [String] = []

    var addCalled = false
    var addedURL: String?
    func add(_ url: String) {
        addCalled = true
        addedURL = url
        cache.append(url)
    }

    var removeCalled = false
    var removedURL: String?
    func remove(_ url: String) {
        removeCalled = true
        removedURL = url
        cache.removeAll { $0 == url }
    }
}
