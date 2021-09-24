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

public protocol HTTPCookieStore {

    func getAllCookies(_ completionHandler: @escaping ([HTTPCookie]) -> Void)

    func setCookie(_ cookie: HTTPCookie, completionHandler: (() -> Void)?)

    func delete(_ cookie: HTTPCookie, completionHandler: (() -> Void)?)

}

protocol WebsiteDataStore {

    var cookieStore: HTTPCookieStore? { get }

    func fetchDataRecords(ofTypes dataTypes: Set<String>, completionHandler: @escaping ([WKWebsiteDataRecord]) -> Void)

    func removeData(ofTypes dataTypes: Set<String>, for dataRecords: [WKWebsiteDataRecord], completionHandler: @escaping () -> Void)

}

internal class WebCacheManager {

    static var shared = WebCacheManager()

    init() { }

    func clear(dataStore: WebsiteDataStore = WKWebsiteDataStore.default(),
               logins: FireproofDomains = FireproofDomains.shared,
               progress: ((Double) -> Void)? = nil,
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
                    let cookiesToRemove = cookies.filter { !logins.isFireproof(cookieDomain: $0.domain) && $0.domain != URL.cookieDomain }
                    dispatchPrecondition(condition: .onQueue(.main))
                    var finished = 0

                    for cookie in cookiesToRemove {
                        group.enter()
                        os_log("Deleting cookie for %s named %s", log: .fire, cookie.domain, cookie.name)
                        cookieStore.delete(cookie) {
                            group.leave()

                            dispatchPrecondition(condition: .onQueue(.main))
                            finished += 1
                            let progressValue = (Double(finished) / Double(cookiesToRemove.count)) * 100
                            DispatchQueue.main.async {
                                progress?(progressValue)
                            }
                        }
                    }
                }

                DispatchQueue.global(qos: .background).async {
                    group.wait()
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }
        }
    }

}

extension WKHTTPCookieStore: HTTPCookieStore {}

extension WKWebsiteDataStore: WebsiteDataStore {

    var cookieStore: HTTPCookieStore? {
        httpCookieStore
    }

}
