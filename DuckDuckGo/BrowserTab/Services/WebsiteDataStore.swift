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

protocol WebsiteCookieStore {

    func getAllCookies(_ completionHandler: @escaping ([HTTPCookie]) -> Void)
    func setCookie(_ cookie: HTTPCookie, completionHandler: (() -> Void)?)
    func delete(_ cookie: HTTPCookie, completionHandler: (() -> Void)?)

}

protocol WebsiteDataStore {

    var cookieStore: WebsiteCookieStore? { get }

    func removeAllData(completionHandler: @escaping () -> Void)

}

class WebCacheManager {

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
            os_log("Cookie store is empty, likely cookies have already been restored", log: .fire, type: .default)
            completion()
            return
        }

        let group = DispatchGroup()

        for cookie in cookies {
            group.enter()
            os_log("Restored cookie for %s with name %s", log: .fire, type: .default, cookie.domain, cookie.name)
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

    func clear(dataStore: WebsiteDataStore = WKWebsiteDataStore.default(),
               appCookieStorage: CookieStorage = CookieStorage(),
               logins: FireproofDomains = FireproofDomains.shared,
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
        os_log("WebsiteDataStore removing all cookie data store data", log: .fire, type: .default)
        dataStore.removeAllData(completionHandler: completion)
    }

    private func extractAllowedCookies(from cookieStore: WebsiteCookieStore?,
                                       cookieStorage: CookieStorage,
                                       logins: FireproofDomains,
                                       completion: @escaping () -> Void) {

        os_log("WebsiteDataStore extracting allowed cookies", log: .fire, type: .default)

        guard let cookieStore = cookieStore else {
            completion()
            return
        }

        cookieStore.getAllCookies { cookies in
            for cookie in cookies {
                if cookie.domain == URL.cookieDomain || logins.isAllowed(cookieDomain: cookie.domain) {
                    cookieStorage.setCookie(cookie)
                    os_log("Saved cookie for %s named %s", log: .fire, type: .default, cookie.domain, cookie.name)
                } else {
                    os_log("Did NOT save cookie for %s named %s", log: .fire, type: .default, cookie.domain, cookie.name)
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

    func removeAllData(completionHandler: @escaping () -> Void) {
        removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                   modifiedSince: Date.distantPast,
                   completionHandler: completionHandler)
    }

}
