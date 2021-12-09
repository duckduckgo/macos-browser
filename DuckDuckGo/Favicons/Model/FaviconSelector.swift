//
//  FaviconSelector.swift
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

final class FaviconSelector {

    static func filterUnnecessaryFaviconLink(faviconLinks: [FaviconUserScript.FaviconLink]) -> [FaviconUserScript.FaviconLink] {
        //TODO: Filter
        return faviconLinks
    }

    static func getMostSuitableFavicon(for sizeCategory: Favicon.SizeCategory, favicons: [Favicon]) -> Favicon? {
        // Create groups according to the relation. // Prioritise favicon, then icon, and others
        let faviconGroups = favicons
            .sorted(by: { $0.image.size.width < $1.image.size.width })
            .reduce(into: [[Favicon](), [Favicon](), [Favicon](), [Favicon]()], { partialResult, favicon in
                if favicon.sizeCategory == sizeCategory {
                    switch favicon.relation {
                    case .favicon: partialResult[0].append(favicon)
                    case .icon: partialResult[1].append(favicon)
                    case .other: partialResult[2].append(favicon)
                    }
                } else {
                    // Use anything larger than size category requirement as default
                    if favicon.image.size.width > sizeCategory.rawValue {
                        partialResult[3].append(favicon)
                    }
                }
            })

        // Pick the most suitable
        for faviconGroup in faviconGroups {
            if let favicon = faviconGroup.first {
                return favicon
            }
        }
        return nil
    }

}
