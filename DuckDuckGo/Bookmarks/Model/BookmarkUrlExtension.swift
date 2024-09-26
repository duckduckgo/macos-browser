//
//  BookmarkUrlExtension.swift
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

extension URL {

    // Generates all possible URL variants for bookmark comparison, including http/https and optional trailing slashes.
    // Variants are only created for URLs with http/https schemes, and trailing slashes are added only if there are no query or fragment components.
    func bookmarkButtonUrlVariants() -> [URL] {
        var baseUrlString = self.absoluteString

        guard let scheme = self.scheme.map(NavigationalScheme.init),
              scheme.isHypertextScheme else {
            return [self]
        }

        baseUrlString = baseUrlString.replacingOccurrences(of: "\(scheme.separated())", with: "")

        // Generate variants without trailing slash
        let withoutTrailingSlash = baseUrlString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // Only append trailing slash if there are no query or fragment components
        let shouldAddTrailingSlash = self.query == nil && self.fragment == nil
        let withTrailingSlash = shouldAddTrailingSlash ? withoutTrailingSlash + "/" : withoutTrailingSlash

        // Create variants
        let httpVariant = NavigationalScheme.http.separated() + withoutTrailingSlash
        let httpsVariant = NavigationalScheme.https.separated() + withoutTrailingSlash
        let httpVariantWithSlash = NavigationalScheme.http.separated() + withTrailingSlash
        let httpsVariantWithSlash = NavigationalScheme.https.separated() + withTrailingSlash
        let variants: [URL?] = [
            self,
            URL(string: httpVariant),
            URL(string: httpsVariant),
            shouldAddTrailingSlash ? URL(string: httpVariantWithSlash) : nil,
            shouldAddTrailingSlash ? URL(string: httpsVariantWithSlash) : nil
        ]

        var seen = Set<String>()
        return variants.compactMap { variant in
            guard let url = variant else { return nil }
            let normalizedUrl = url.absoluteString.lowercased()
            if seen.contains(normalizedUrl) {
                return nil  // Skip if already added
            }
            seen.insert(normalizedUrl)
            return url
        }
    }
}
