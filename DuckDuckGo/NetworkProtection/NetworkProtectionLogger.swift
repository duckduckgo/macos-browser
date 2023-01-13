//
//  NetworkProtectionLogger.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import NetworkExtension
import OSLog

protocol NetworkProtectionLogger {
    func log(_ error: Error)
}

final class DefaultNetworkProtectionLogger: NetworkProtectionLogger {
    func log(_ error: Error) {
        let format = StaticString(stringLiteral: "🔴 %{public}@")
        os_log(format, type: .error, error.localizedDescription)

        let nsError = error as NSError

        /// Note: `configurationReadWriteFailed` is raised when the user does not grant permission to access the system's VPN info (which we should ignore),
        /// but the error code's description makes it sound like it could signal other issues with reading and writing the VPN configuration, which we don't want to ignore by default.
        /// For this reason we're keeping the log but disabling the assertion for this error code.
        ///
        let skipAssertion = nsError.domain == NEVPNErrorDomain && nsError.code == NEVPNError.configurationReadWriteFailed.rawValue

        if !skipAssertion {
            assertionFailure(error.localizedDescription)
        }
    }
}
