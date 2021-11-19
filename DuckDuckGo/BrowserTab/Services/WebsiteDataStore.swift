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
import GRDB
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
    func removeData(ofTypes dataTypes: Set<String>, modifiedSince date: Date, completionHandler: @escaping () -> Void)

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

    func clear(completion: @escaping () -> Void) {

        let types = WKWebsiteDataStore.allWebsiteDataTypesExceptCookies

        websiteDataStore.removeData(ofTypes: types, modifiedSince: Date.distantPast) {
            guard let cookieStore = self.websiteDataStore.cookieStore else {
                completion()
                return
            }

            cookieStore.getAllCookies { cookies in
                let group = DispatchGroup()
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
                
                self.removeResourceLoadStatisticsDatabase()

                group.notify(queue: .main) {
                    completion()
                }
            }
        }
    }

    func clear(domains: Set<String>? = nil,
               completion: @escaping () -> Void) {

        let all = WKWebsiteDataStore.allWebsiteDataTypes()
        let allExceptCookies = WKWebsiteDataStore.allWebsiteDataTypesExceptCookies

        websiteDataStore.fetchDataRecords(ofTypes: all) { [weak self] records in

            // Remove all data except cookies for all domains, and then filter cookies to preserve those allowed by Fireproofing.
            self?.websiteDataStore.removeData(ofTypes: allExceptCookies, for: records) { [weak self] in
                guard let self = self else { return }

                guard let cookieStore = self.websiteDataStore.cookieStore else {
                    completion()
                    return
                }

                cookieStore.getAllCookies { cookies in
                    let group = DispatchGroup()

                    var cookies = cookies
                    if let domains = domains {
                        // If domains are specified, clear just their cookies
                        cookies = cookies.filter { cookie in
                            domains.contains {
                                $0 == cookie.domain
                                || ".\($0)" == cookie.domain
                                || (cookie.domain.hasPrefix(".") && $0.hasSuffix(cookie.domain))
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
                    
                    self.removeResourceLoadStatisticsDatabase()

                    group.notify(queue: .main) {
                        completion()
                    }
                }
            }
        }
    }
    
    // WKWebView doesn't provide a way to remove the observations database, which contains domains that have been
    // visited by the user. This database is removed directly as a part of the Fire button process.
    private func removeResourceLoadStatisticsDatabase() {
        guard let bundleID = Bundle.main.bundleIdentifier,
              var libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return
        }

        libraryURL.appendPathComponent("WebKit/\(bundleID)/WebsiteData/ResourceLoadStatistics")
        
        let contentsOfDirectory = (try? FileManager.default.contentsOfDirectory(at: libraryURL, includingPropertiesForKeys: [.nameKey])) ?? []
        let fileNames = contentsOfDirectory.compactMap(\.suggestedFilename)
        
        guard fileNames.contains("observations.db") else {
            return
        }

        // We've confirmed that the observations.db exists, now it can be cleaned out. We can't delete it entirely, as
        // WebKit won't recreate it until next app launch.
        
        let databasePath = libraryURL.appendingPathComponent("observations.db")

        guard let pool = try? DatabasePool(path: databasePath.absoluteString) else {
            return
        }
        
        try? pool.write { database in
            let tables = try String.fetchAll(database, sql: "SELECT name FROM sqlite_master WHERE type='table'")
            
            for table in tables {
                try database.execute(sql: "DELETE FROM \(table)")
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
