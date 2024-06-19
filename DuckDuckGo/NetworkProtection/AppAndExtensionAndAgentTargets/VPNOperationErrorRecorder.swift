//
//  VPNOperationErrorRecorder.swift
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
import NetworkProtectionIPC

@objc
final class ErrorInformation: NSObject, Codable {
    let domain: String
    let code: Int

    init(_ error: Error) {
        let nsError = error as NSError

        domain = nsError.domain
        code = nsError.code
    }
}

/// This class provides information about VPN operation errors.
///
/// To be used in combination with ``VPNOperationErrorRecorder``
///
final class VPNOperationErrorHistory {

    private let ipcClient: VPNControllerXPCClient
    private let defaults: UserDefaults

    init(ipcClient: VPNControllerXPCClient,
         defaults: UserDefaults = .netP) {

        self.ipcClient = ipcClient
        self.defaults = defaults
    }

    /// The earliest error is the one that best represents the latest failure
    ///
    var lastStartError: ErrorInformation? {
        lastIPCStartError ?? lastControllerStartError
    }

    var lastStartErrorDescription: String {
        lastStartError.map { errorInformation in
            "Error domain=\(errorInformation.domain) code=\(errorInformation.code)"
        } ?? "none"
    }

    private var lastIPCStartError: ErrorInformation? {
        defaults.vpnIPCStartError
    }

    private var lastControllerStartError: ErrorInformation? {
        defaults.controllerStartError
    }

    var lastTunnelError: ErrorInformation? {
        get async {
            await withCheckedContinuation { (continuation: CheckedContinuation<ErrorInformation?, Never>) in
                ipcClient.fetchLastError { error in
                    if let error {
                        continuation.resume(returning: ErrorInformation(error))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    var lastTunnelErrorDescription: String {
        get async {
            await lastTunnelError.map { errorInformation in
                "Error domain=\(errorInformation.domain) code=\(errorInformation.code)"
            } ?? "none"
        }
    }
}

/// This class records information about recent errors during VPN operation.
///
/// To be used in combination with ``VPNOperationErrorHistory``
///
final class VPNOperationErrorRecorder {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .netP) {
        self.defaults = defaults
    }

    // IPC Errors

    func beginRecordingIPCStart() {
        defaults.vpnIPCStartError = nil
    }

    func recordIPCStartFailure(_ error: Error) {
        defaults.vpnIPCStartError = ErrorInformation(error)
    }

    // VPN Controller Errors

    func beginRecordingControllerStart() {
        defaults.controllerStartError = nil

        // This needs a special note because it may be non-obvious.  The thing is users
        // can start the VPN directly from the menu app, and in this case we want IPC
        // errors to be cleared because they have priority in the reporting.  Additionally
        // if the controller is starting the VPN we can safely assume there was no IPC
        // error in the current start attempt, so resetting ipc start errors should be fine,
        // regardless.
        defaults.vpnIPCStartError = nil
    }

    func recordControllerStartFailure(_ error: Error) {
        defaults.controllerStartError = ErrorInformation(error)
    }
}

fileprivate extension UserDefaults {
    private var vpnIPCStartErrorKey: String {
        "vpnIPCStartError"
    }

    @objc
    dynamic var vpnIPCStartError: ErrorInformation? {
        get {
            guard let payload = data(forKey: vpnIPCStartErrorKey) else {
                return nil
            }

            return try? JSONDecoder().decode(ErrorInformation.self, from: payload)
        }

        set {
            guard let newValue,
                  let payload = try? JSONEncoder().encode(newValue) else {

                removeObject(forKey: vpnIPCStartErrorKey)
                return
            }

            set(payload, forKey: vpnIPCStartErrorKey)
        }
    }
}

fileprivate extension UserDefaults {
    private var controllerStartErrorKey: String {
        "controllerStartError"
    }

    @objc
    dynamic var controllerStartError: ErrorInformation? {
        get {
            guard let payload = data(forKey: controllerStartErrorKey) else {
                return nil
            }

            return try? JSONDecoder().decode(ErrorInformation.self, from: payload)
        }

        set {
            guard let newValue,
                  let payload = try? JSONEncoder().encode(newValue) else {

                removeObject(forKey: controllerStartErrorKey)
                return
            }

            set(payload, forKey: controllerStartErrorKey)
        }
    }
}
