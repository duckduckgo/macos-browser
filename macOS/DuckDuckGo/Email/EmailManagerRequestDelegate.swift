//
//  EmailManagerRequestDelegate.swift
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

import BrowserServicesKit

extension EmailManagerRequestDelegate {

    // swiftlint:disable function_parameter_count
    func emailManager(_ emailManager: EmailManager, requested url: URL, method: String, headers: [String: String], parameters: [String: String]?, httpBody: Data?, timeoutInterval: TimeInterval) async throws -> Data {

        let finalURL = url.appendingParameters(parameters ?? [:])

        var request = URLRequest(url: finalURL, timeoutInterval: timeoutInterval)
        request.allHTTPHeaderFields = headers
        request.httpMethod = method
        request.httpBody = httpBody

        return try await URLSession.default.data(for: request).0
    }
    // swiftlint:enable function_parameter_count

    public func emailManagerKeychainAccessFailed(accessType: EmailKeychainAccessType, error: EmailKeychainAccessError) {
        var parameters = [
            "access_type": accessType.rawValue,
            "error": error.errorDescription
        ]

        if case let .keychainLookupFailure(status) = error {
            parameters["keychain_status"] = String(status)
            parameters["keychain_operation"] = "lookup"
        }

        if case let .keychainDeleteFailure(status) = error {
            parameters["keychain_status"] = String(status)
            parameters["keychain_operation"] = "delete"
        }

        if case let .keychainSaveFailure(status) = error {
            parameters["keychain_status"] = String(status)
            parameters["keychain_operation"] = "save"
        }

        Pixel.fire(.debug(event: .emailAutofillKeychainError), withAdditionalParameters: parameters)
    }

}
