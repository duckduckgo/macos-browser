//
//  Tab+NSSecureCoding.swift
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

import Foundation

extension Tab: NSSecureCoding {
    // MARK: - Coding

    private enum NSCodingKeys {
        static let url = "url"
        static let title = "title"
        static let configuration = "configuration"
        static let sessionStateData = "ssdata"
        static let favicon = "icon"
    }

    static var supportsSecureCoding: Bool { true }

    convenience init?(coder decoder: NSCoder) {
        self.init(webViewConfiguration: decoder.decodeIfPresent(at: NSCodingKeys.configuration),
                  url: decoder.decodeIfPresent(at: NSCodingKeys.url),
                  title: decoder.decodeIfPresent(at: NSCodingKeys.title),
                  favicon: decoder.decodeIfPresent(at: NSCodingKeys.favicon),
                  sessionStateData: decoder.decodeIfPresent(at: NSCodingKeys.sessionStateData))
    }

    public func encode(with coder: NSCoder) {
        let configuration = webView.configuration
        guard configuration.websiteDataStore.isPersistent == true else { return }

        url.map(coder.encode(forKey: NSCodingKeys.url))
        title.map(coder.encode(forKey: NSCodingKeys.title))
        coder.encode(configuration, forKey: NSCodingKeys.configuration)
        favicon.map(coder.encode(forKey: NSCodingKeys.favicon))
        getActualSessionStateData().map(coder.encode(forKey: NSCodingKeys.sessionStateData))
    }

}
