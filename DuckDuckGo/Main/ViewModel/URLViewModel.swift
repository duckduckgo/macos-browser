//
//  URLViewModel.swift
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

import Foundation
import os.log

class URLViewModel {

    let url: URL

    init(url: URL) {
        self.url = url
    }

    convenience init?(addressBarString: String) {
        guard let url = URL.makeURL(from: addressBarString) else {
            return nil
        }

        self.init(url: url)
    }

    var addressBarRepresentation: String {
        url.searchQuery ?? url.host ?? ""
    }

}

fileprivate extension URL {

    static func makeSearchUrl(from searchQuery: String) -> URL? {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            var searchUrl = Self.duckduckgo
            try searchUrl.addParameter(name: DuckduckgoParameters.search.rawValue, value: trimmedQuery)
            return searchUrl
        } catch let error {
            os_log("URL extension: %s", log: generalLog, type: .error, error.localizedDescription)
            return nil
        }
    }

    static func makeURL(from addressBarString: String) -> URL? {
        if let addressBarUrl = addressBarString.url {
            return addressBarUrl
        }

        if let searchUrl = URL.makeSearchUrl(from: addressBarString) {
            return searchUrl
        }

        os_log("URL extension: Making URL from %s failed", log: generalLog, type: .error, addressBarString)
        return nil
    }
    
}
