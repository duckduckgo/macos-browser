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

protocol WebsiteDataStore {

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

        dataStore.fetchDataRecords(ofTypes: all) { records in
            let recordsToRemove = records.filter {
                print("CHECKING \($0.displayName)")
                return !logins.isAllowed(recordDomain: $0.displayName) && $0.displayName != URL.cookieDomain
            }

            for record in recordsToRemove {
                os_log("WebCacheManager removing record for %s", log: .fire, type: .default, record.displayName)
            }

            dataStore.removeData(ofTypes: all, for: recordsToRemove, completionHandler: completion)
        }
    }

}

extension WKWebsiteDataStore: WebsiteDataStore {}
