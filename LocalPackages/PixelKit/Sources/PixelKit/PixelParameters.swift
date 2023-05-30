//
//  PixelParameters.swift
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

extension Pixel {

    enum Parameters {
        static let duration = "duration"
        static let test = "test"
        static let appVersion = "appVersion"

        static let keychainFieldName = "fieldName"
        static let errorCode = "e"
        static let errorDesc = "d"
        static let errorCount = "c"
        static let underlyingErrorCode = "ue"
        static let underlyingErrorDesc = "ud"
        static let underlyingErrorSQLiteCode = "sqlrc"
        static let underlyingErrorSQLiteExtendedCode = "sqlerc"
    }

    enum Values {
        static let test = "1"
    }
}

extension Error {

    public var pixelParameters: [String: String] {
        var parameters = [String: String]()
        let nsError = self as NSError

        parameters[Pixel.Parameters.errorCode] = "\(nsError.code)"
        parameters[Pixel.Parameters.errorDesc] = nsError.domain
        if let underlyingError = nsError.userInfo["NSUnderlyingError"] as? NSError {
            parameters[Pixel.Parameters.underlyingErrorCode] = "\(underlyingError.code)"
            parameters[Pixel.Parameters.underlyingErrorDesc] = underlyingError.domain
        }

        if let sqlErrorCode = nsError.userInfo["SQLiteResultCode"] as? NSNumber {
            parameters[Pixel.Parameters.underlyingErrorSQLiteCode] = "\(sqlErrorCode.intValue)"
        }

        if let sqlExtendedErrorCode = nsError.userInfo["SQLiteExtendedResultCode"] as? NSNumber {
            parameters[Pixel.Parameters.underlyingErrorSQLiteExtendedCode] = "\(sqlExtendedErrorCode.intValue)"
        }

        return parameters
    }

}
