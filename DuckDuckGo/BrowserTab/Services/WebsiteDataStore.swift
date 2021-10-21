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

    private let fireproofDomains: FireproofDomains
    private let websiteDataStore: WebsiteDataStore

    init(fireproofDomains: FireproofDomains = FireproofDomains.shared,
         websiteDataStore: WebsiteDataStore = WKWebsiteDataStore.default()) {
        self.fireproofDomains = fireproofDomains
        self.websiteDataStore = websiteDataStore
    }

    func clear(domains: Set<String>? = nil,
               completion: @escaping () -> Void) {

        let all = WKWebsiteDataStore.allWebsiteDataTypes()
        let allExceptCookies = all.filter { $0 != "WKWebsiteDataTypeCookies" }

        websiteDataStore.fetchDataRecords(ofTypes: all) { [weak self] records in

            // Remove all data except cookies for all domains, and then filter cookies to preserve those allowed by Fireproofing.
            self?.websiteDataStore.removeData(ofTypes: allExceptCookies, for: records) { [weak self] in
                guard let self = self else { return }

                guard let cookieStore = self.websiteDataStore.cookieStore else {
                    completion()
                    return
                }

                let group = DispatchGroup()
                group.enter()
                cookieStore.getAllCookies { cookies in
                    var cookies = cookies
                    if let domains = domains {
                        // If domains are specified, clear just their cookies
                        cookies = cookies.filter { cookie in
                            domains.contains { domain in
                                cookie.domain.isSubdomain(of: domain)
                            }
                        }
                    }
                    // Don't clear fireproof domains
                    let cookiesToRemove = cookies.filter { cookie in
                        !self.fireproofDomains.isFireproof(cookieDomain: cookie.domain) && cookie.domain != URL.cookieDomain
                    }

                    for cookie in cookiesToRemove {
                        group.enter()
                        os_log("Deleting cookie for %s named %s", log: .fire, cookie.domain, cookie.name)
                        cookieStore.delete(cookie) {
                            group.leave()
                        }
                    }

                    group.leave()
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
