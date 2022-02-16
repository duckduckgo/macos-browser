//
//  DeviceAuthenticator.swift
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

final class DeviceAuthenticator {
    
    private let idleStateDetector: DeviceIdleStateDetector
    private let authenticationService: DeviceAuthenticationService
    private let loginsPreferences: LoginsPreferences
    
    init(idleStateDetector: DeviceIdleStateDetector = .shared,
         authenticationService: DeviceAuthenticationService = LocalAuthenticationService(),
         loginsPreferences: LoginsPreferences) {
        self.idleStateDetector = idleStateDetector
        self.authenticationService = authenticationService
        self.loginsPreferences = loginsPreferences
    }
    
    var requiresAuthorization: Bool {
        return idleStateDetector.secondsSinceLastEvent >= loginsPreferences.autoLockThreshold.seconds
    }

    func authorizeDevice(result: @escaping (Bool) -> Void) {
        guard requiresAuthorization else {
            result(true)
            return
        }
        
        authenticationService.authenticateDevice(result: result)
    }
    
}
