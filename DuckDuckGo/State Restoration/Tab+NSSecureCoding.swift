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

    private enum NSSecureCodingKeys {
        static let url = "url"
        static let title = "title"
        static let sessionStateData = "ssdata"
        static let favicon = "icon"
        static let tabType = "tabType"
        static let preferencePane = "preferencePane"
        static let visitedDomains = "visitedDomains"
    }

    static var supportsSecureCoding: Bool { true }

    convenience init?(coder decoder: NSCoder) {
        let url: URL? = decoder.decodeIfPresent(at: NSSecureCodingKeys.url)
        let preferencePane = decoder.decodeIfPresent(at: NSSecureCodingKeys.preferencePane)
            .flatMap(PreferencePaneIdentifier.init(rawValue:))

        guard let tabTypeRawValue: Int = decoder.decodeIfPresent(at: NSSecureCodingKeys.tabType),
              let tabType = TabContent.ContentType(rawValue: tabTypeRawValue),
              let content = TabContent(type: tabType, url: url, preferencePane: preferencePane)
        else { return nil }

        let visitedDomains = decoder.decodeObject(of: [NSArray.self, NSString.self], forKey: NSSecureCodingKeys.visitedDomains) as? [String] ?? []

        self.init(content: content,
                  localHistory: Set(visitedDomains),
                  title: decoder.decodeIfPresent(at: NSSecureCodingKeys.title),
                  favicon: decoder.decodeIfPresent(at: NSSecureCodingKeys.favicon),
                  sessionStateData: decoder.decodeIfPresent(at: NSSecureCodingKeys.sessionStateData))
    }

    func encode(with coder: NSCoder) {
        guard webView.configuration.websiteDataStore.isPersistent == true else { return }

        content.url.map(coder.encode(forKey: NSSecureCodingKeys.url))
        coder.encode(Array(localHistory), forKey: NSSecureCodingKeys.visitedDomains)
        title.map(coder.encode(forKey: NSSecureCodingKeys.title))
        favicon.map(coder.encode(forKey: NSSecureCodingKeys.favicon))
        getActualSessionStateData().map(coder.encode(forKey: NSSecureCodingKeys.sessionStateData))
        coder.encode(content.type.rawValue, forKey: NSSecureCodingKeys.tabType)
        if let pane = content.preferencePane {
            coder.encode(pane.rawValue, forKey: NSSecureCodingKeys.preferencePane)
        }
    }

}

private extension Tab.TabContent {

    enum ContentType: Int, CaseIterable {
        case url = 0
        case preferences = 1
        case bookmarks = 2
        case homePage = 3
        case onboarding = 4
    }

    init?(type: ContentType, url: URL?, preferencePane: PreferencePaneIdentifier?) {
        switch type {
        case .homePage:
            self = .homePage
        case .url:
            guard let url = url else { return nil }
            self = .url(url)
        case .bookmarks:
            self = .bookmarks
        case .preferences:
            self = .preferences(pane: preferencePane)
        case .onboarding:
            self = .onboarding
        }
    }

    var type: ContentType {
        switch self {
        case .url: return .url
        case .homePage: return .homePage
        case .bookmarks: return .bookmarks
        case .preferences: return .preferences
        case .onboarding: return .onboarding
        case .none: return .homePage
        }
    }

    var preferencePane: PreferencePaneIdentifier? {
        switch self {
        case let .preferences(pane: pane):
            return pane
        default:
            return nil
        }
    }
}
