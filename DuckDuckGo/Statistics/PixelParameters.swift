//
//  PixelParameters.swift
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

extension Pixel {

    public struct Parameters {
        public static let duration = "dur"
        static let test = "test"
        static let appVersion = "appVersion"

        static let errorCode = "e"
        static let errorDesc = "d"
        static let errorCount = "c"
        static let underlyingErrorCode = "ue"
        static let underlyingErrorDesc = "ud"
    }

    public struct Values {
        static let test = "1"
    }

}

extension Pixel.Event {

    var parameters: [String: String]? {
        switch self {
        case .debug(event: let event, error: let error, countedBy: let counter):
            let nsError = error as NSError
            var params = [
                Pixel.Parameters.errorCode: "\(nsError.code)",
                Pixel.Parameters.errorDesc: nsError.domain
            ]

            if let counter = counter {
                let count = counter.incrementedCount(for: event)
                params[Pixel.Parameters.errorCount] = "\(count)"
            }

            if let underlyingError = nsError.userInfo["NSUnderlyingError"] as? NSError {
                params[Pixel.Parameters.underlyingErrorCode] = "\(underlyingError.code)"
                params[Pixel.Parameters.underlyingErrorDesc] = underlyingError.domain
            } else if let sqlErrorCode = nsError.userInfo["NSSQLiteErrorDomain"] as? NSNumber {
                params[Pixel.Parameters.underlyingErrorCode] = "\(sqlErrorCode.intValue)"
                params[Pixel.Parameters.underlyingErrorDesc] = "NSSQLiteErrorDomain"
            }

            return params

        case .appLaunch,
             .appActiveUsage,
             .burn,
             .fireproof,
             .bookmark,
             .favorite,
             .navigation,
             .suggestionsDisplayed,
             .sharingMenu,
             .moreMenu,
             .refresh:

            return nil
        }
    }

}
