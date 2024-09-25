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

    func bookmarkButtonUrlVariants() -> [URL] {
        var baseUrlString = self.absoluteString

        // Remove the scheme if it's http or https
        if let scheme = self.scheme.map(NavigationalScheme.init),
           scheme.isHypertextScheme {
            baseUrlString = baseUrlString.replacingOccurrences(of: "\(scheme.separated())", with: "")
        }

        // Generate variants
        let withoutTrailingSlash = baseUrlString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let withTrailingSlash = withoutTrailingSlash + "/"
        let httpVariant = NavigationalScheme.http.separated() + withoutTrailingSlash
        let httpsVariant = NavigationalScheme.https.separated() + withoutTrailingSlash
        let httpVariantWithSlash = NavigationalScheme.http.separated() + withTrailingSlash
        let httpsVariantWithSlash = NavigationalScheme.https.separated() + withTrailingSlash

        let variants: [URL?] = [
            self,                                  // Original URL
            URL(string: httpVariant),              // http without trailing slash
            URL(string: httpsVariant),             // https without trailing slash
            URL(string: httpVariantWithSlash),     // http with trailing slash
            URL(string: httpsVariantWithSlash)     // https with trailing slash
        ]

        // Filter out nil values and remove duplicates while preserving order
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
