//
//  WebsiteInfo.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

struct WebsiteInfo: Equatable {
    let url: URL
    /// Returns the title of the website if available, otherwise returns the domain of the URL.
    /// If both title and and domain are nil, it returns the absolute string representation of the URL.
    let title: String

    init?(_ tab: Tab) {
        guard case let .url(url, _, _) = tab.content else {
            return nil
        }
        self.url = url
        self.title = tab.title ?? url.host ?? url.absoluteString
    }
}
