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
import Common
import os.log

extension NSNotification.Name {

    static let deviceBecameLocked = NSNotification.Name("deviceBecameLocked")

}

protocol UserAuthenticating {
    func authenticateUser(reason: DeviceAuthenticator.AuthenticationReason, result: @escaping (DeviceAuthenticationResult) -> Void)
    func authenticateUser(reason: DeviceAuthenticator.AuthenticationReason) async -> DeviceAuthenticationResult
}

final class DeviceAuthenticator: UserAuthenticating {

    enum AuthenticationReason {
        case autofill
        case autofillCreditCards
        case changeLoginsSettings
        case unlockLogins
        case exportLogins
        case syncSettings
        case deleteAllPasswords
        case viewAllCredentials

        var localizedDescription: String {
            switch self {
            case .autofill, .autofillCreditCards: return UserText.pmAutoLockPromptAutofill
            case .changeLoginsSettings: return UserText.pmAutoLockPromptChangeLoginsSettings
            case .unlockLogins: return UserText.pmAutoLockPromptUnlockLogins
            case .exportLogins: return UserText.pmAutoLockPromptExportLogins
            case .syncSettings: return UserText.syncAutoLockPrompt
            case .deleteAllPasswords: return UserText.deleteAllPasswordsPermissionText
            case .viewAllCredentials: return UserText.pmAutoLockPromptUnlockLogins
            }
        }
    }

    internal enum Constants {
        static var intervalBetweenIdleChecks: TimeInterval = 1
        static var intervalBetweenCreditCardAutofillChecks: TimeInterval = 10
        static var intervalBetweenSyncSettingsChecks: TimeInterval = 15
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
    private var timerCreditCard: Timer?
    private var timerSyncSettings: Timer?

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

            Logger.autoLock.debug("Device lock state changed: \(self.deviceIsLocked ? "locked" : "unlocked", privacy: .public)")

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
        guard NSApp.runType != .uiTests else {
            result(.success)
            return
        }

        let needsAuthenticationForCreditCardsAutofill = reason == .autofillCreditCards && isCreditCardTimeIntervalExpired()
        let needsAuthenticationForSyncSettings = reason == .syncSettings && isSyncSettingsTimeIntervalExpired()
        let needsAuthenticationForDeleteAllPasswords = reason == .deleteAllPasswords
        let needsAuthenticationForViewAllCredentials = reason == .viewAllCredentials
        guard needsAuthenticationForCreditCardsAutofill || needsAuthenticationForSyncSettings || needsAuthenticationForDeleteAllPasswords || needsAuthenticationForViewAllCredentials ||
                requiresAuthentication else {
            result(.success)
            return
        }

        Logger.autoLock.debug("Began authenticating")

        isAuthenticating = true

        authenticationService.authenticateDevice(reason: reason.localizedDescription) { authenticationResult in
            Logger.autoLock.debug("Completed authenticating, with result: \(authenticationResult.authenticated, privacy: .public)")

            self.isAuthenticating = false
            self.deviceIsLocked = !authenticationResult.authenticated

            if authenticationResult.authenticated {
                // Now that the user has unlocked the device, begin the idle timer again.
                self.beginIdleCheckTimer()
                self.beginCreditCardAutofillTimer()
                self.beginSyncSettingsTimer()
            }

            result(authenticationResult)
        }
    }

    func authenticateUser(reason: DeviceAuthenticator.AuthenticationReason) async -> DeviceAuthenticationResult {
        await withCheckedContinuation { continuation in
            authenticateUser(reason: reason) { result in
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Idle Timer Monitoring

    private func beginIdleCheckTimer() {
        Logger.autoLock.debug("Beginning idle check timer")

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
        Logger.autoLock.debug("Cancelling idle check timer")
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
            Logger.autoLock.debug("Tried to start idle timer while device was already locked")
            return
        }

        guard autofillPreferences.isAutoLockEnabled else {
            Logger.autoLock.debug("Tried to start idle timer but device should not auto-lock")
            return
        }

        beginIdleCheckTimer()
    }

    private func checkIdleTimeIntervalAndLockIfNecessary(interval: TimeInterval) {
        if interval >= autofillPreferences.autoLockThreshold.seconds {
            self.lock()
        }
    }

    // MARK: - Credit Card Autofill Timer

    private func beginCreditCardAutofillTimer() {
        Logger.autoLock.debug("Beginning credit card autofill timer")

        self.timerCreditCard?.invalidate()
        self.timerCreditCard = nil

        let timer = Timer(timeInterval: Constants.intervalBetweenCreditCardAutofillChecks, repeats: false) { [weak self] _ in
            guard let self = self else {
                return
            }
            self.cancelCreditCardAutofillTimer()
        }

        self.timerCreditCard = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    private func cancelCreditCardAutofillTimer() {
        Logger.autoLock.debug("Cancelling credit card autofill timer")
        self.timerCreditCard?.invalidate()
        self.timerCreditCard = nil
    }

    private func isCreditCardTimeIntervalExpired() -> Bool {
        guard let timer = timerCreditCard else {
            return true
        }
        return timer.timeInterval >= Constants.intervalBetweenCreditCardAutofillChecks
    }

    // MARK: - Sync Timer

    private func beginSyncSettingsTimer() {
        Logger.autoLock.debug("Beginning Sync Settings timer")

        self.timerSyncSettings?.invalidate()
        self.timerSyncSettings = nil

        let timer = Timer(timeInterval: Constants.intervalBetweenSyncSettingsChecks, repeats: false) { [weak self] _ in
            guard let self = self else {
                return
            }
            self.cancelSyncSettingsTimer()
        }

        self.timerSyncSettings = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    private func cancelSyncSettingsTimer() {
        Logger.autoLock.debug("Cancelling Sync Settings timer")
        self.timerSyncSettings?.invalidate()
        self.timerSyncSettings = nil
    }

    private func isSyncSettingsTimeIntervalExpired() -> Bool {
        guard let timer = timerSyncSettings else {
            return true
        }
        return timer.timeInterval >= Constants.intervalBetweenSyncSettingsChecks
    }

}
