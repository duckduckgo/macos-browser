//
//  DataBrokerProtectionEmailService.swift
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

public struct DataBrokerProtectionEmailService {

    public enum EmailError: Error, Equatable {
        case cantGenerateURL
        case cantFindEmail
    }

    // This authentication method will be replaced with https://app.asana.com/0/72649045549333/1203580969735029/f
    private struct Constants {
        static let baseUrl = "https://dbp.duckduckgo.com/dbp/em/v0"
        static let authUser = ""
        static let authPass = ""
    }

    public let urlSession: URLSession

    public init(urlSession: URLSession = URLSession.shared) {
        self.urlSession = urlSession
    }

    func getEmail() async throws -> String {
        guard let url = URL(string: Constants.baseUrl + "/generate") else {
            throw EmailError.cantGenerateURL
        }

        var request = URLRequest(url: url)
        let base64Login = authAsBase64HeaderValue(user: Constants.authUser, key: Constants.authPass)

        request.setValue(base64Login, forHTTPHeaderField: "Authorization")
        let (data, _) = try await urlSession.data(for: request)

        if let resJson = try? JSONSerialization.jsonObject(with: data) as? [String: AnyObject],
           let email = resJson["emailAddress"] as? String {
            return email
        } else {
            throw EmailError.cantFindEmail
        }
    }

    private func authAsBase64HeaderValue(user: String, key: String) -> String {
        let loginStr = String(format: "%@:%@", user, key)
        let loginData = loginStr.data(using: .utf8)!
        return "Basic \(loginData.base64EncodedString())"
    }
}
