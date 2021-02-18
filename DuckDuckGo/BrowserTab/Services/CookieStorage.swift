//
//  CookieStorage.swift
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
import os.log

private typealias Cookie = [String: Any?]

class CookieStorage {

    @UserDefaultsWrapper(key: .allowedCookies, defaultValue: [])
    private var allowedCookies: [Cookie]

    var cookies: [HTTPCookie] {
        var storedCookies = [HTTPCookie]()

            for cookieData in allowedCookies {
                var properties = [HTTPCookiePropertyKey: Any]()

                cookieData.forEach {
                    properties[HTTPCookiePropertyKey(rawValue: $0.key)] = $0.value
                }

                if let cookie = HTTPCookie(properties: properties) {
                    storedCookies.append(cookie)
                }
            }

        return storedCookies
    }

    func clear() {
        allowedCookies = []
    }

    func setCookie(_ cookie: HTTPCookie) {
        var cookieData = Cookie()

        cookie.properties?.forEach {
            cookieData[$0.key.rawValue] = $0.value
        }

        cookieData[HTTPCookiePropertyKey.sameSitePolicy.rawValue] = cookie.sameSitePolicy ?? HTTPCookieStringPolicy.sameSiteLax

        setCookie(cookieData)
    }

    private func setCookie(_ cookieData: Cookie) {
        allowedCookies.append(cookieData)
    }

}
