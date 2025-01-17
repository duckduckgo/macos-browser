//
//  LocalAuthenticationService.swift
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

import Foundation
import LocalAuthentication

final class LocalAuthenticationService: DeviceAuthenticationService {

    func authenticateDevice(reason: String, result: @escaping DeviceAuthenticationResultHandler) {
        let context = LAContext()

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            result(.noAuthAvailable)
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { authenticated, _ in
            DispatchQueue.main.async {
                let authenticationResult: DeviceAuthenticationResult = authenticated ? .success : .failure
                result(authenticationResult)
            }
        }
    }

}
