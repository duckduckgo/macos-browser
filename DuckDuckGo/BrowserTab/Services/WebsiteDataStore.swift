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
    func allCookies() async -> [HTTPCookie]
    func setCookie(_ cookie: HTTPCookie) async
    func deleteCookie(_ cookie: HTTPCookie) async
}

protocol WebsiteDataStore {
    var cookieStore: HTTPCookieStore? { get }

    func dataRecords(ofTypes dataTypes: Set<String>) async -> [WKWebsiteDataRecord]
    func removeData(ofTypes dataTypes: Set<String>, modifiedSince date: Date) async
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

    func clear(domains: Set<String>? = nil) async {
        // first cleanup ~/Library/Caches
        await self.clearFileCache()

        await removeAllDataExceptCookies()

        await removeCookies(forDomains: domains)

        await self.removeResourceLoadStatisticsDatabase()
    }

    private func clearFileCache() async {
        let fm = FileManager.default
        let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Bundle.main.bundleIdentifier!)
        let tmpDir = fm.temporaryDirectory(appropriateFor: cachesDir).appendingPathComponent(UUID().uuidString)

        do {
            try fm.createDirectory(at: tmpDir, withIntermediateDirectories: false, attributes: nil)
        } catch {
            os_log("Could not create temporary directory: %s", type: .error, "\(error)")
            return
        }

        let contents = try? fm.contentsOfDirectory(atPath: cachesDir.path)
        for name in contents ?? [] {
            guard ["WebKit", "fsCachedData"].contains(name) || name.hasPrefix("Cache.") else { continue }
            try? fm.moveItem(at: cachesDir.appendingPathComponent(name), to: tmpDir.appendingPathComponent(name))
        }

        try? fm.createDirectory(at: cachesDir.appendingPathComponent("WebKit"),
                                withIntermediateDirectories: false,
                                attributes: nil)

        Process("/bin/rm", "-rf", tmpDir.path).launch()
    }

    @MainActor
    private func removeAllDataExceptCookies() async {
        let allExceptCookies = WKWebsiteDataStore.allWebsiteDataTypesExceptCookies

        // Remove all data except cookies for all domains, and then filter cookies to preserve those allowed by Fireproofing.
        await websiteDataStore.removeData(ofTypes: allExceptCookies, modifiedSince: Date.distantPast)
    }

    @MainActor
    private func removeCookies(forDomains domains: Set<String>? = nil) async {
        guard let cookieStore = websiteDataStore.cookieStore else { return }
        var cookies = await cookieStore.allCookies()

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
            os_log("Deleting cookie for %s named %s", log: .fire, cookie.domain, cookie.name)
            await cookieStore.deleteCookie(cookie)
        }
    }
    
    // WKWebView doesn't provide a way to remove the observations database, which contains domains that have been
    // visited by the user. This database is removed directly as a part of the Fire button process.
    private func removeResourceLoadStatisticsDatabase() async {
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
