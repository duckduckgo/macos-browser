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

    private var idleStateDetector: DeviceIdleStateDetector? = nil
    private let authenticationService: DeviceAuthenticationService
    private let loginsPreferences: LoginsPreferences
    
    init(authenticationService: DeviceAuthenticationService = LocalAuthenticationService(),
         loginsPreferences: LoginsPreferences = LoginsPreferences()) {
        self.authenticationService = authenticationService
        self.loginsPreferences = loginsPreferences
    }
    
    private(set) var isAuthenticating: Bool = false
    private(set) var deviceIsLocked: Bool = true
    
    var requiresAuthentication: Bool {
        guard loginsPreferences.shouldAutoLockLogins else {
            return false
        }

        return deviceIsLocked
    }
    
    func beginCheckingIdleTimer() {
        if self.idleStateDetector == nil {
            self.idleStateDetector = DeviceIdleStateDetector(idleTimeCallback: self.checkIdleTimeIntervalAndLockIfNecessary(interval:))
        }
        
        guard !deviceIsLocked && loginsPreferences.shouldAutoLockLogins else {
            os_log("Tried to start idle timer while device was already locked", log: .autoLock)
            return
        }
        
        os_log("Beginning idle timer", log: .autoLock)
        idleStateDetector?.beginIdleCheckTimer()
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
            
            self.isAuthenticating = false
            self.deviceIsLocked = !authenticated
            
            if authenticated {
                // Now that the user has unlocked the device, begin the idle timer again.
                self.idleStateDetector?.beginIdleCheckTimer()
            }
            
            result(authenticated)
        }
    }
    
    private func checkIdleTimeIntervalAndLockIfNecessary(interval: TimeInterval) {
        if interval >= loginsPreferences.autoLockThreshold.seconds {
            os_log("Device locked!", log: .autoLock)
            
            self.deviceIsLocked = true
            self.idleStateDetector?.cancelIdleCheckTimer()
        }
    }
    
}
