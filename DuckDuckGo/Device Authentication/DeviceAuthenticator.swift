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
import LocalAuthentication
import os.log

extension NSNotification.Name {

    static let deviceBecameLocked = NSNotification.Name("deviceBecameLocked")

}

final class DeviceAuthenticator {
    
    static var deviceSupportsBiometrics: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    static let shared = DeviceAuthenticator()

    private var idleStateDetector: DeviceIdleStateDetector?
    private let authenticationService: DeviceAuthenticationService
    private let loginsPreferences: LoginsPreferences

    private(set) var isAuthenticating: Bool = false
    private(set) var deviceIsLocked: Bool {
        didSet {
            os_log("Device lock state changed: %s", log: .autoLock, deviceIsLocked ? "locked" : "unlocked")
            
            if deviceIsLocked {
                NotificationCenter.default.post(name: .deviceBecameLocked, object: nil)
            }
        }
    }
    
    init(authenticationService: DeviceAuthenticationService = LocalAuthenticationService(),
         loginsPreferences: LoginsPreferences = LoginsPreferences()) {
        self.authenticationService = authenticationService
        self.loginsPreferences = loginsPreferences
        self.deviceIsLocked = loginsPreferences.shouldAutoLockLogins
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateTimerStateBasedOnAutoLockSettings),
                                               name: .loginsAutoLockSettingsDidChange,
                                               object: nil)
    }
    
    var requiresAuthentication: Bool {
        // shouldAutoLockLogins can only be changed by the user authenticating themselves, so it's safe to
        // use it to early return from the authentication check.
        guard loginsPreferences.shouldAutoLockLogins else {
            return false
        }

        return deviceIsLocked
    }
    
    @objc
    private func updateTimerStateBasedOnAutoLockSettings() {
        let preferences = LoginsPreferences()
        
        if preferences.shouldAutoLockLogins {
            beginCheckingIdleTimer()
        } else {
            self.idleStateDetector?.cancelIdleCheckTimer()
        }
    }
    
    func beginCheckingIdleTimer() {
        if self.idleStateDetector == nil {
            self.idleStateDetector = DeviceIdleStateDetector(idleTimeCallback: self.checkIdleTimeIntervalAndLockIfNecessary(interval:))
        }
        
        guard !deviceIsLocked else {
            os_log("Tried to start idle timer while device was already locked", log: .autoLock)
            return
        }
        
        guard loginsPreferences.shouldAutoLockLogins else {
            os_log("Tried to start idle timer but device should not auto-lock", log: .autoLock)
            return
        }
        
        idleStateDetector?.beginIdleCheckTimer()
    }

    func authenticateUser(result: @escaping (Bool) -> Void) {
        guard requiresAuthentication else {
            result(true)
            return
        }
        
        os_log("Began authenticating", log: .autoLock)
        
        isAuthenticating = true

        authenticationService.authenticateDevice(reason: UserText.pmAutoLockPromptUnlockLogins) { authenticated in
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
            self.deviceIsLocked = true
            self.idleStateDetector?.cancelIdleCheckTimer()
        }
    }
    
}
