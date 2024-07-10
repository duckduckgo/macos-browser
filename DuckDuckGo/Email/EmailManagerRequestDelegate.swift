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
import PixelKit

extension EmailManagerRequestDelegate {

    public var activeTask: URLSessionTask? {
        get { return nil }
        set {}
    }

    func emailManager(_ emailManager: EmailManager, requested url: URL, method: String, headers: [String: String], parameters: [String: String]?, httpBody: Data?, timeoutInterval: TimeInterval) async throws -> Data {
        let finalURL = url.appendingParameters(parameters ?? [:])
        var request = URLRequest(url: finalURL, timeoutInterval: timeoutInterval)
        request.allHTTPHeaderFields = headers
        request.httpMethod = method
        request.httpBody = httpBody

        activeTask?.cancel() // Cancel active request (if any)

        let (data, response) = try await URLSession.shared.data(for: request)
        activeTask = URLSession.shared.dataTask(with: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 300 {
            throw EmailManagerRequestDelegateError.serverError(statusCode: httpResponse.statusCode)
        }

        return data
    }

    public func emailManagerKeychainAccessFailed(_ emailManager: EmailManager, accessType: EmailKeychainAccessType, error: EmailKeychainAccessError) {
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

        PixelKit.fire(DebugEvent(GeneralPixel.emailAutofillKeychainError), withAdditionalParameters: parameters)
    }

}
