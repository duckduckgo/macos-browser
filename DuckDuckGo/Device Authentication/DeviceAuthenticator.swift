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
import os.log

final class DeviceAuthenticator {
    
    static let shared = DeviceAuthenticator()

    private let idleStateDetector: DeviceIdleStateDetector
    private let authenticationService: DeviceAuthenticationService
    private let loginsPreferences: LoginsPreferences
    
    init(idleStateDetector: DeviceIdleStateDetector = .shared,
         authenticationService: DeviceAuthenticationService = LocalAuthenticationService(),
         loginsPreferences: LoginsPreferences = LoginsPreferences()) {
        self.idleStateDetector = idleStateDetector
        self.authenticationService = authenticationService
        self.loginsPreferences = loginsPreferences
    }
    
    private(set) var isAuthenticating: Bool = false
    private(set) var deviceIsLocked: Bool = false
    
    var requiresAuthentication: Bool {
        guard loginsPreferences.shouldAutoLockLogins else {
            return false
        }

        let requiresAuthentication = idleStateDetector.maximumIdleStateIntervalSinceLastAuthentication >= loginsPreferences.autoLockThreshold.seconds
        os_log("Checked authentication, with result: %{bool}d", log: .autoLock, requiresAuthentication)

        return requiresAuthentication
    }

    func authorizeDevice(result: @escaping (Bool) -> Void) {
        guard requiresAuthentication else {
            result(true)
            return
        }
        
        os_log("Began authenticating", log: .autoLock)
        
        isAuthenticating = true

        authenticationService.authenticateDevice { authenticated in
            os_log("Completed authenticating, with result: %{bool}d", log: .autoLock, authenticated)
            
            if authenticated {
                self.idleStateDetector.resetIdleStateDuration()
            }
            
            self.isAuthenticating = false
            
            result(authenticated)
        }
    }
    
}
