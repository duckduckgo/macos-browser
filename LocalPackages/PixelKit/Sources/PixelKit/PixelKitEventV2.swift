//
//  PixelKitEventV2.swift
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

public protocol PixelKitEventErrorDetails: Error {
    var underlyingError: Error? { get }
}

extension PixelKitEventErrorDetails {
    var underlyingErrorParameters: [String: String] {
        guard let nsError = underlyingError as? NSError else {
            return [:]
        }

        return [
            PixelKit.Parameters.underlyingErrorCode: "\(nsError.code)",
            PixelKit.Parameters.underlyingErrorDomain: nsError.domain
        ]
    }
}

/// New version of this protocol that allows us to maintain backwards-compatibility with PixelKitEvent
///
/// This new implementation seeks to unify the handling of standard pixel parameters inside PixelKit.
/// The starting example of how this can be useful is error parameter handling - this protocol allows
/// the implementer to specify an error without having to know about its parameterisation.
///
/// The reason this wasn't done directly in `PixelKitEvent` is to reduce the risk of breaking existing
/// pixels, and to allow us to migrate towards this incrementally.
///
public protocol PixelKitEventV2: PixelKitEvent {
    var error: Error? { get }
}

extension PixelKitEventV2 {
    var pixelParameters: [String: String] {
        guard let error else {
            return [:]
        }

        let nsError = error as NSError
        var parameters = [
            PixelKit.Parameters.errorCode: "\(nsError.code)",
            PixelKit.Parameters.errorDomain: nsError.domain,
        ]

        if let error = error as? PixelKitEventErrorDetails {
            parameters.merge(error.underlyingErrorParameters, uniquingKeysWith: { $1 })
        }

        return parameters
    }
}
