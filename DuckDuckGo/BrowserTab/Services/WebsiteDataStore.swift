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

protocol WebsiteCookieStore {

    func getAllCookies(_ completionHandler: @escaping ([HTTPCookie]) -> Void)

    func setCookie(_ cookie: HTTPCookie, completionHandler: (() -> Void)?)

    func delete(_ cookie: HTTPCookie, completionHandler: (() -> Void)?)

}

protocol WebsiteDataStore {

    var cookieStore: WebsiteCookieStore? { get }

    func removeAllData(_ completionHandler: @escaping () -> Void)

}

class WebCacheManager {

    private struct Constants {
        static let cookieDomain = "duckduckgo.com"
    }

    static var shared = WebCacheManager()

    init() { }

    func consumeCookies(cookieStorage: CookieStorage = CookieStorage(),
                        httpCookieStore: WebsiteCookieStore? = WKWebsiteDataStore.default().cookieStore,
                        completion: @escaping () -> Void) {

        guard let httpCookieStore = httpCookieStore else {
            completion()
            return
        }

        let cookies = cookieStorage.cookies

        guard !cookies.isEmpty else {
            completion()
            return
        }

        let group = DispatchGroup()

        for cookie in cookies {
            group.enter()
            httpCookieStore.setCookie(cookie) {
                group.leave()
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            group.wait()

            DispatchQueue.main.async {
                cookieStorage.clear()
                completion()
            }
        }
    }

    func removeCookies(forDomains domains: [String],
                       dataStore: WebsiteDataStore = WKWebsiteDataStore.default(),
                       completion: @escaping () -> Void) {

        guard let cookieStore = dataStore.cookieStore else {
            completion()
            return
        }

        cookieStore.getAllCookies { cookies in
            let group = DispatchGroup()
            cookies.forEach { cookie in
                domains.forEach { domain in

                    if self.isDuckDuckGoOrAllowedDomain(cookie: cookie, domain: domain) {
                        group.enter()
                        cookieStore.delete(cookie) {
                            group.leave()
                        }

                        // don't try to delete the cookie twice as it doesn't always work (esecially on the simulator)
                        return
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

    func clear(dataStore: WebsiteDataStore = WKWebsiteDataStore.default(),
               appCookieStorage: CookieStorage = CookieStorage(),
               logins: PreserveLogins = PreserveLogins.shared,
               completion: @escaping () -> Void) {
        extractAllowedCookies(from: dataStore.cookieStore, cookieStorage: appCookieStorage, logins: logins) {
            self.clearAllData(dataStore: dataStore, completion: completion)
        }
    }

    /// The Fire Button does not delete the user's DuckDuckGo search settings, which are saved as cookies.
    /// Removing these cookies would reset them and have undesired consequences, i.e. changing the theme, default language, etc.
    /// These cookies are not stored in a personally identifiable way. For example, the large size setting is stored as 's=l.'
    /// More info in https://duckduckgo.com/privacy
    private func isDuckDuckGoOrAllowedDomain(cookie: HTTPCookie, domain: String) -> Bool {
        return cookie.domain == domain || (cookie.domain.hasPrefix(".") && domain.hasSuffix(cookie.domain))
    }

    private func clearAllData(dataStore: WebsiteDataStore, completion: @escaping () -> Void) {
        dataStore.removeAllData(completion)
    }

    private func extractAllowedCookies(from cookieStore: WebsiteCookieStore?,
                                       cookieStorage: CookieStorage,
                                       logins: PreserveLogins,
                                       completion: @escaping () -> Void) {

        guard let cookieStore = cookieStore else {
            completion()
            return
        }

        cookieStore.getAllCookies { cookies in
            for cookie in cookies {
                if cookie.domain == Constants.cookieDomain || logins.isAllowed(cookieDomain: cookie.domain) {
                    cookieStorage.setCookie(cookie)
                }
            }
            completion()
        }

    }

}

extension WKHTTPCookieStore: WebsiteCookieStore {}

extension WKWebsiteDataStore: WebsiteDataStore {

    var cookieStore: WebsiteCookieStore? {
        return self.httpCookieStore
    }

    func removeAllData(_ completionHandler: @escaping () -> Void) {
        removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                   modifiedSince: Date.distantPast,
                   completionHandler: completionHandler)
    }

}
