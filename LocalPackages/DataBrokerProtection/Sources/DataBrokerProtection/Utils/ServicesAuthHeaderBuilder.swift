//
//  ServicesAuthHeaderBuilder.swift
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

struct ServicesAuthHeaderBuilder {

    /**
     * Receives an auth token and returns the header value as expected by our services
     *
     * - Parameters:
     *    - token: The authentication token to be included in the header
     *
     * - Returns: The formatted header value with the token included, or nil if the token is nil or empty
     */
    public func getAuthHeader(_ token: String?) -> String? {
        guard let token = token, !token.isEmpty else {
            return nil
        }
        return "bearer \(token)"
    }

}
