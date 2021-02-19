//
//  WebsiteDataStore.swift
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

import WebKit
import os

public protocol WebCacheManagerCookieStore {

    func getAllCookies(_ completionHandler: @escaping ([HTTPCookie]) -> Void)

    func setCookie(_ cookie: HTTPCookie, completionHandler: (() -> Void)?)

    func delete(_ cookie: HTTPCookie, completionHandler: (() -> Void)?)

}

protocol WebsiteDataStore {

    var cookieStore: WebCacheManagerCookieStore? { get }

    func fetchDataRecords(ofTypes dataTypes: Set<String>, completionHandler: @escaping ([WKWebsiteDataRecord]) -> Void)

    func removeData(ofTypes dataTypes: Set<String>, for dataRecords: [WKWebsiteDataRecord], completionHandler: @escaping () -> Void)

}

class WebCacheManager {

    static var shared = WebCacheManager()

    init() { }

    func clear(dataStore: WebsiteDataStore = WKWebsiteDataStore.default(),
               logins: FireproofDomains = FireproofDomains.shared,
               completion: @escaping () -> Void) {

        let all = WKWebsiteDataStore.allWebsiteDataTypes()
        let allExceptCookies = all.filter { $0 != "WKWebsiteDataTypeCookies" }

        dataStore.fetchDataRecords(ofTypes: all) { records in

            // Remove all data except cookies for all domains, and then filter cookies to preserve those allowed by Fireproofing.
            dataStore.removeData(ofTypes: allExceptCookies, for: records) {
                guard let cookieStore = dataStore.cookieStore else {
                    completion()
                    return
                }

                let group = DispatchGroup()

                cookieStore.getAllCookies { cookies in
                    let cookiesToRemove = cookies.filter { !logins.isAllowed(cookieDomain: $0.domain) && $0.domain != URL.cookieDomain }

                    for cookie in cookiesToRemove {
                        group.enter()
                        os_log("Deleting cookie for %s named %s", log: .fire, cookie.domain, cookie.name)
                        cookieStore.delete(cookie) {
                            group.leave()
                        }
                    }
                }

                DispatchQueue.global(qos: .background).async {
                    _ = group.wait(timeout: .now() + 5)
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }
        }
    }

}

extension WKHTTPCookieStore: WebCacheManagerCookieStore {}

extension WKWebsiteDataStore: WebsiteDataStore {

    var cookieStore: WebCacheManagerCookieStore? {
        httpCookieStore
    }

}
