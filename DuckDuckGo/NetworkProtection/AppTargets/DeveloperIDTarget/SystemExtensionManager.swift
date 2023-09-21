//
//  SystemExtensionManager.swift
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
import Cocoa
import Combine
@preconcurrency import SystemExtensions
import PixelKit

struct SystemExtensionManager {

    enum ActivationRequestEvent {
        case waitingForUserApproval
        case activated
        case willActivateAfterReboot
    }

    private static let systemSettingsSecurityURL = "x-apple.systempreferences:com.apple.preference.security?Security"

    private let bundleID: String
    private let manager: OSSystemExtensionManager
    private let workspace: NSWorkspace

    init(bundleID: String = NetworkProtectionBundle.extensionBundle().bundleIdentifier!,
         manager: OSSystemExtensionManager = .shared,
         workspace: NSWorkspace = .shared) {

        self.bundleID = bundleID
        self.manager = manager
        self.workspace = workspace
    }

    func activate() -> AsyncThrowingStream<ActivationRequestEvent, Error> {
        /// Documenting a workaround for the issue discussed in https://app.asana.com/0/0/1205275221447702/f
        ///     Background: For a lot of users, the system won't show the system-extension-blocked alert if there's a previous request
        ///         to activate the extension.  You can see active requests in your console using command `systemextensionsctl list`.
        ///
        ///     Proposed workaround: Just open system settings into the right section when we detect a previous activation request already exists.
        ///
        ///     Tradeoffs: Unfortunately we don't know if the previous request was sent out by the currently runing-instance of this App
        ///         or if an activation request was made, and then the App was reopened.
        ///         This means we don't know if we'll be notified when the previous activation request completes or fails.  Because we
        ///         need to update our UI once the extension is allowed, we can't avoid sending a new activation request every time.
        ///         For the users that don't see the alert come up more than once this should be invisible.  For users (like myself) that
        ///         see the alert every single time, they'll see both the alert and system settings being opened automatically.
        ///
        if hasPendingActivationRequests() {
            openSystemSettingsSecurity()
        }

        return SystemExtensionRequest.activationRequest(forExtensionWithIdentifier: bundleID, manager: manager).submit()
    }

    func deactivate() async throws {
        for try await _ in SystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: bundleID, manager: manager).submit() {}
    }

    // MARK: - Activation: Checking if there are pending requests

    /// Checks if there are pending activation requests for the system extension.
    ///
    /// This implementation should work well for all macOS 11+ releases.  A better implementation for macOS 12+
    /// would be to use a properties request, but that option requires bigger changes and some rethinking of these
    /// classes which I'd rather avoid right now.  In short this solution was picked as a quick solution with the best
    /// ROI to avoid getting blocked.
    ///
    private func hasPendingActivationRequests() -> Bool {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.launchPath = "/bin/bash" // Specify the shell to use
        task.arguments = ["-c", "$(which systemextensionsctl) list | $(which egrep) -c '(?:\(bundleID)).+(?:activated waiting for user)+'"]

        task.launch()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

        return (Int(output ?? "0") ?? 0) > 0
    }

    private func openSystemSettingsSecurity() {
        let url = URL(string: Self.systemSettingsSecurityURL)!
        workspace.open(url)
    }
}

final class SystemExtensionRequest: NSObject {
    typealias Event = SystemExtensionManager.ActivationRequestEvent

    private let request: OSSystemExtensionRequest
    private let manager: OSSystemExtensionManager

    private var continuation: AsyncThrowingStream<Event, Error>.Continuation?

    private init(request: OSSystemExtensionRequest, manager: OSSystemExtensionManager) {
        self.manager = manager
        self.request = request

        super.init()
    }

    static func activationRequest(forExtensionWithIdentifier bundleId: String, manager: OSSystemExtensionManager) -> Self {
        self.init(request: .activationRequest(forExtensionWithIdentifier: bundleId, queue: .global()), manager: manager)
    }

    static func deactivationRequest(forExtensionWithIdentifier bundleId: String, manager: OSSystemExtensionManager) -> Self {
        self.init(request: .deactivationRequest(forExtensionWithIdentifier: bundleId, queue: .global()), manager: manager)
    }

    /// submitting the request returns an Async Iterator providing the OSSystemExtensionRequest state change events
    /// until an Event is received.
    func submit() -> AsyncThrowingStream<Event, Error> {
        assert(continuation == nil, "Request can only be submitted once")

        defer {
            request.delegate = self
            manager.submitRequest(request)
        }
        return AsyncThrowingStream { [self /* keep the request delegate alive */] continuation in
            continuation.onTermination = { _ in
                withExtendedLifetime(self) {}
            }
            self.continuation = continuation
        }
    }
}

extension SystemExtensionRequest: OSSystemExtensionRequestDelegate {

    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {

        return .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        continuation?.yield(.waitingForUserApproval)
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        switch result {
        case .completed:
            continuation?.yield(.activated)
        case .willCompleteAfterReboot:
            continuation?.yield(.willActivateAfterReboot)
        @unknown default:
            // Not much we can do about this, so let's assume it's a good result and not show any errors
            continuation?.yield(.activated)
            // TODO: verify this works fine
            PixelKit.fire(.networkProtectionSystemExtensionUnknownActivationResult, frequency: .standard)
        }

        continuation?.finish()
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        continuation?.finish(throwing: error)
    }

}
