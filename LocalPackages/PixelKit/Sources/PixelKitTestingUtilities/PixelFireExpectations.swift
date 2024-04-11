//
//  PixelFireExpectations.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import PixelKit

/// Structure containing information about a pixel fire event.
///
/// This is useful for test validation for libraries that rely on PixelKit, to make sure the pixels contain
/// all of the fields they are supposed to contain..
///
public struct PixelFireExpectations {
    let pixelName: String
    var error: Error?
    var underlyingErrors: [Error]
    var customFields: [String: String]?

    /// Convenience initializer for cleaner semantics
    ///
    public static func expect(pixelName: String, error: Error? = nil, underlyingErrors: [Error] = [], customFields: [String: String]? = nil) -> PixelFireExpectations {

        .init(pixelName: pixelName, error: error, underlyingErrors: underlyingErrors, customFields: customFields)
    }

    public init(pixelName: String, error: Error? = nil, underlyingErrors: [Error] = [], customFields: [String: String]? = nil) {
        self.pixelName = pixelName
        self.error = error
        self.underlyingErrors = underlyingErrors
        self.customFields = customFields
    }

    public var parameters: [String: String] {
        var parameters = customFields ?? [String: String]()

        if let nsError = error as? NSError {
            parameters[PixelKit.Parameters.errorCode] = String(nsError.code)
            parameters[PixelKit.Parameters.errorDomain] = nsError.domain
        }

        for (index, error) in underlyingErrors.enumerated() {
            let errorCodeParameterName = PixelKit.Parameters.underlyingErrorCode + (index == 0 ? "" : String(index + 1))
            let errorDomainParameterName = PixelKit.Parameters.underlyingErrorDomain + (index == 0 ? "" : String(index + 1))
            let nsError = error as NSError

            parameters[errorCodeParameterName] = String(nsError.code)
            parameters[errorDomainParameterName] = nsError.domain
        }

        return parameters
    }
}
