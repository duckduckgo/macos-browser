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

protocol UserAuthenticating {
    func authenticateUser(reason: DeviceAuthenticator.AuthenticationReason, result: @escaping (DeviceAuthenticationResult) -> Void)
}

final class DeviceAuthenticator: UserAuthenticating {

    enum AuthenticationReason {
        case autofill
        case changeLoginsSettings
        case unlockLogins
        case exportLogins

        var localizedDescription: String {
            switch self {
            case .autofill: return UserText.pmAutoLockPromptAutofill
            case .changeLoginsSettings: return UserText.pmAutoLockPromptChangeLoginsSettings
            case .unlockLogins: return UserText.pmAutoLockPromptUnlockLogins
            case .exportLogins: return UserText.pmAutoLockPromptExportLogins
            }
        }
    }

    internal enum Constants {
        static var intervalBetweenIdleChecks: TimeInterval = 1
    }

    static var deviceSupportsBiometrics: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    static let shared = DeviceAuthenticator()

    // MARK: - Public

    private(set) var isAuthenticating: Bool {
        get {
            return queue.sync {
                _isAuthenticating
            }
        }

        set (newState) {
            queue.sync {
                self._isAuthenticating = newState
            }
        }
    }

    func lock() {
        self.deviceIsLocked = true
        self.cancelIdleCheckTimer()
    }

    // MARK: - Private Dependencies

    private var idleStateProvider: DeviceIdleStateProvider
    private let authenticationService: DeviceAuthenticationService
    private let autofillPreferences: AutofillPreferences

    // MARK: - Private State

    private let queue = DispatchQueue(label: "Device Authenticator Queue")

    private var timer: Timer?

    private var _isAuthenticating: Bool = false
    private var _deviceIsLocked: Bool = false

    private var deviceIsLocked: Bool {
        get {
            return queue.sync {
                _deviceIsLocked
            }
        }

        set (newState) {
            queue.sync {
                self._deviceIsLocked = newState
            }

            os_log("Device lock state changed: %s", log: .autoLock, deviceIsLocked ? "locked" : "unlocked")

            if newState {
                NotificationCenter.default.post(name: .deviceBecameLocked, object: nil)
            }
        }
    }

    init(idleStateProvider: DeviceIdleStateProvider = QuartzIdleStateProvider(),
         authenticationService: DeviceAuthenticationService = LocalAuthenticationService(),
         autofillPreferences: AutofillPreferences = AutofillPreferences()) {
        self.idleStateProvider = idleStateProvider
        self.authenticationService = authenticationService
        self.autofillPreferences = autofillPreferences
        self.deviceIsLocked = autofillPreferences.isAutoLockEnabled

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateTimerStateBasedOnAutoLockSettings),
                                               name: .autofillAutoLockSettingsDidChange,
                                               object: nil)
    }

    var requiresAuthentication: Bool {
        // shouldAutoLockLogins can only be changed by the user authenticating themselves, so it's safe to
        // use it to early return from the authentication check.
        guard shouldAutoLockLogins else {
            return false
        }

        return deviceIsLocked
    }

    var shouldAutoLockLogins: Bool {
        autofillPreferences.isAutoLockEnabled
    }

    func authenticateUser(reason: AuthenticationReason, result: @escaping (DeviceAuthenticationResult) -> Void) {
        guard requiresAuthentication else {
            result(.success)
            return
        }

        os_log("Began authenticating", log: .autoLock)

        isAuthenticating = true

        authenticationService.authenticateDevice(reason: reason.localizedDescription) { authenticationResult in
            os_log("Completed authenticating, with result: %{bool}d", log: .autoLock, authenticationResult.authenticated)

            self.isAuthenticating = false
            self.deviceIsLocked = !authenticationResult.authenticated

            if authenticationResult.authenticated {
                // Now that the user has unlocked the device, begin the idle timer again.
                self.beginIdleCheckTimer()
            }

            result(authenticationResult)
        }
    }

    func authenticateUser(reason: AuthenticationReason) async -> DeviceAuthenticationResult {
        await withCheckedContinuation { continuation in
            authenticateUser(reason: reason) { result in
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Idle Timer Monitoring

    private func beginIdleCheckTimer() {
        os_log("Beginning idle check timer", log: .autoLock)

        self.timer?.invalidate()
        self.timer = nil

        let timer = Timer(timeInterval: Constants.intervalBetweenIdleChecks, repeats: true) { [weak self] _ in
            guard let self = self else {
                return
            }

            self.checkIdleTimeIntervalAndLockIfNecessary(interval: self.idleStateProvider.secondsSinceLastEvent())
        }

        self.timer = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    private func cancelIdleCheckTimer() {
        os_log("Cancelling idle check timer", log: .autoLock)
        self.timer?.invalidate()
        self.timer = nil
    }

    @objc
    private func updateTimerStateBasedOnAutoLockSettings() {
        let preferences = AutofillPreferences()

        if preferences.isAutoLockEnabled {
            beginCheckingIdleTimer()
        } else {
            cancelIdleCheckTimer()
        }
    }

    func beginCheckingIdleTimer() {
        guard !deviceIsLocked else {
            os_log("Tried to start idle timer while device was already locked", log: .autoLock)
            return
        }

        guard autofillPreferences.isAutoLockEnabled else {
            os_log("Tried to start idle timer but device should not auto-lock", log: .autoLock)
            return
        }

        beginIdleCheckTimer()
    }

    private func checkIdleTimeIntervalAndLockIfNecessary(interval: TimeInterval) {
        if interval >= autofillPreferences.autoLockThreshold.seconds {
            self.lock()
        }
    }

}
