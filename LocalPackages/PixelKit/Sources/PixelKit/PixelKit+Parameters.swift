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

    enum Parameters: Hashable {
        public static let duration = "duration"
        public static let test = "test"
        public static let appVersion = "appVersion"
        public static let pixelSource = "pixelSource"
        public static let osMajorVersion = "osMajorVersion"

        public static let errorCode = "e"
        public static let errorDomain = "d"
        public static let errorCount = "c"
        public static let errorSource = "error_source"
        public static let sourceBrowserVersion = "source_browser_version"
        public static let underlyingErrorCode = "ue"
        public static let underlyingErrorDomain = "ud"
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

        // Dashboard
        public static let dashboardTriggerOrigin = "trigger_origin"

        // VPN
        public static let vpnBreakageCategory = "breakageCategory"
        public static let vpnBreakageDescription = "breakageDescription"
        public static let vpnBreakageMetadata = "breakageMetadata"

        public static let reason = "reason"

        public static let vpnCohort = "cohort"
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
        params[PixelKit.Parameters.errorDomain] = nsError.domain

        let underlyingErrorParameters = self.underlyingErrorParameters(for: nsError)
        params.merge(underlyingErrorParameters) { first, _ in
            return first
        }

        if let sqlErrorCode = nsError.userInfo["SQLiteResultCode"] as? NSNumber {
            params[PixelKit.Parameters.underlyingErrorSQLiteCode] = "\(sqlErrorCode.intValue)"
        }

        if let sqlExtendedErrorCode = nsError.userInfo["SQLiteExtendedResultCode"] as? NSNumber {
            params[PixelKit.Parameters.underlyingErrorSQLiteExtendedCode] = "\(sqlExtendedErrorCode.intValue)"
        }

        return params
    }

    /// Recursive call to add underlying error information
    ///
    func underlyingErrorParameters(for nsError: NSError, level: Int = 0) -> [String: String] {
        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            let errorCodeParameterName = PixelKit.Parameters.underlyingErrorCode + (level == 0 ? "" : String(level + 1))
            let errorDomainParameterName = PixelKit.Parameters.underlyingErrorDomain + (level == 0 ? "" : String(level + 1))

            let currentUnderlyingErrorParameters = [
                errorCodeParameterName: "\(underlyingError.code)",
                errorDomainParameterName: underlyingError.domain
            ]

            // Check if the underlying error has an underlying error of its own
            let additionalParameters = underlyingErrorParameters(for: underlyingError, level: level + 1)

            return currentUnderlyingErrorParameters.merging(additionalParameters) { first, _ in
                return first // Doesn't really matter as there should be no conflict of parameters
            }
        }

        return [:]
    }
}
