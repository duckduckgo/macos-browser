//
//  WKWebsiteDataStoreExtension.swift
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

import WebKit

extension WKWebsiteDataStore {

    /// All website data types except cookies. This set includes those types not publicly declared by WebKit.
    /// Cookies are not removed as they are handled separately by the Fire button logic.
    ///
    /// - note: The full list of data types can be found in the [WKWebsiteDataStore](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/API/Cocoa/WKWebsiteDataRecord.mm) documentation.
    static var allWebsiteDataTypesExceptCookies: Set<String> {
        var types = Self.allWebsiteDataTypes()

        types.insert("_WKWebsiteDataTypeMediaKeys")
        types.insert("_WKWebsiteDataTypeHSTSCache")
        types.insert("_WKWebsiteDataTypeSearchFieldRecentSearches")
        types.insert("_WKWebsiteDataTypeResourceLoadStatistics")
        types.insert("_WKWebsiteDataTypeCredentials")
        types.insert("_WKWebsiteDataTypeAdClickAttributions")
        types.insert("_WKWebsiteDataTypePrivateClickMeasurements")
        types.insert("_WKWebsiteDataTypeAlternativeServices")

        types.remove(WKWebsiteDataTypeCookies)

        return types
    }

    /// All website data types that are safe to remove from all domains, regardless of their Fireproof status. This set includes those types not publicly declared by WebKit.
    /// Cookies are not removed as they are handled separately by the Fire button logic.
    ///
    /// - note: The full list of data types can be found in the [WKWebsiteDataStore](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/API/Cocoa/WKWebsiteDataRecord.mm) documentation.
    static var safelyRemovableWebsiteDataTypes: Set<String> {
        var types = Self.allWebsiteDataTypesExceptCookies

        types.remove(WKWebsiteDataTypeLocalStorage)

        // Only Fireproof IndexedDB on macOS 12.2+. Earlier versions have a privacy flaw that can expose browsing history.
        // More info: https://fingerprintjs.com/blog/indexeddb-api-browser-vulnerability-safari-15
        if #available(macOS 12.2, *) {
            types.remove(WKWebsiteDataTypeIndexedDBDatabases)
        }

        return types
    }

}
