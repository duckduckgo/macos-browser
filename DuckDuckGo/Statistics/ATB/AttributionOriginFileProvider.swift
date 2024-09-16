//
//  AttributionOriginFileProvider.swift
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

/// A type that provides the `origin` used to anonymously track installations without tracking retention.
protocol AttributionOriginProvider: AnyObject {
    /// A string representing the acquisition funnel.
    var origin: String? { get }
}

final class AttributionOriginFileProvider: AttributionOriginProvider {
    let origin: String?

    /// Creates an instance with the given file name and `Bundle`.
    /// - Parameters:
    ///   - name: The name of the Txt file to extract the origin from.
    ///   - bundle: The bundle where the file is located. In tests pass replace this with the test bundle.
    init(resourceName name: String = "Origin", bundle: Bundle = .main) {
        let url = bundle.url(forResource: name, withExtension: "txt")
        origin = try? url
            .flatMap(String.init(contentsOf:))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        return isEmpty ? nil : self
    }
}
