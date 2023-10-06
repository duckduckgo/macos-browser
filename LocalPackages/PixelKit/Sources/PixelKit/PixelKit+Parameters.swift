//
//  PixelKit+Parameters.swift
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

public extension PixelKit {

    enum Parameters {
        public static let duration = "duration"
        public static let test = "test"
        public static let appVersion = "appVersion"

        public static let errorCode = "e"
        public static let errorDesc = "d"
        public static let errorCount = "c"
        public static let underlyingErrorCode = "ue"
        public static let underlyingErrorDesc = "ud"
        public static let underlyingErrorSQLiteCode = "sqlrc"
        public static let underlyingErrorSQLiteExtendedCode = "sqlerc"

        public static let keychainFieldName = "fieldName"
        public static let keychainErrorCode = "keychain_error_code"

        public static let emailCohort = "cohort"
        public static let emailLastUsed = "duck_address_last_used"

        public static let assertionMessage = "message"
        public static let assertionFile = "file"
        public static let assertionLine = "line"

        public static let function = "function"
        public static let line = "line"

        public static let latency = "latency"
        public static let server = "server"
        public static let networkType = "net_type"

        // Pixel experiments
        public static let experimentCohort = "cohort"
    }

    enum Values {
        public static let test = "1"
    }

}

public protocol ErrorWithPixelParameters {

    var errorParameters: [String: String] { get }

}

public extension Error {

    var pixelParameters: [String: String] {
        var params = [String: String]()

        if let errorWithUserInfo = self as? ErrorWithPixelParameters {
            params = errorWithUserInfo.errorParameters
        }

        let nsError = self as NSError

        params[PixelKit.Parameters.errorCode] = "\(nsError.code)"
        params[PixelKit.Parameters.errorDesc] = nsError.domain

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            params[PixelKit.Parameters.underlyingErrorCode] = "\(underlyingError.code)"
            params[PixelKit.Parameters.underlyingErrorDesc] = underlyingError.domain
        }

        if let sqlErrorCode = nsError.userInfo["SQLiteResultCode"] as? NSNumber {
            params[PixelKit.Parameters.underlyingErrorSQLiteCode] = "\(sqlErrorCode.intValue)"
        }

        if let sqlExtendedErrorCode = nsError.userInfo["SQLiteExtendedResultCode"] as? NSNumber {
            params[PixelKit.Parameters.underlyingErrorSQLiteExtendedCode] = "\(sqlExtendedErrorCode.intValue)"
        }

        return params
    }

}
