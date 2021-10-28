//
//  WebsiteDataStoreMock.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class WebCacheManagerMock: WebCacheManager {

    var clearCalled = false
    override func clear(domains: Set<String>? = nil,
                        completion: @escaping () -> Void) {
        clearCalled = true
        completion()
    }

}

extension HTTPCookie {

    static func make(name: String = "name",
                     value: String = "value",
                     domain: String = "example.com",
                     path: String = "/",
                     policy: HTTPCookieStringPolicy? = nil) -> HTTPCookie {

        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path
        ]

        if #available(iOS 13, *), policy != nil {
            properties[HTTPCookiePropertyKey.sameSitePolicy] = policy
        }

        return HTTPCookie(properties: properties)!
    }

}
