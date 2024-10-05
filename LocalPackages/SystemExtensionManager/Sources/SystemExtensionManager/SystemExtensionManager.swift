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
import SystemExtensions

public enum SystemExtensionRequestError: Error {
    case unknownRequestResult
    case willActivateAfterReboot
}

public struct SystemExtensionManager {

    private static var systemSettingsSecurityURL: String {
        if #available(macOS 15, *) {
            return "x-apple.systempreferences:com.apple.LoginItems-Settings.extension?ExtensionItems"
        } else {
            return "x-apple.systempreferences:com.apple.preference.security?Security"
        }
    }

    private let extensionBundleID: String
    private let manager: OSSystemExtensionManager
    private let workspace: NSWorkspace

    public init(
        extensionBundleID: String,
        manager: OSSystemExtensionManager = .shared,
        workspace: NSWorkspace = .shared) {

        self.extensionBundleID = extensionBundleID
        self.manager = manager
        self.workspace = workspace
    }

    /// - Returns: The system extension version when it's updated, otherwise `nil`.
    ///
    public func activate(waitingForUserApproval: @escaping () -> Void) async throws -> String? {

        workaroundToActivateBeforeSequoia()

        let activationRequest = SystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionBundleID,
            manager: manager,
            waitingForUserApproval: waitingForUserApproval)

        try await activationRequest.submit()

        return activationRequest.version
    }

    /// Workaround to help make activation easier for users.
    ///
    /// Documenting a workaround for the issue discussed in https://app.asana.com/0/0/1205275221447702/f
    ///
    /// ## Background:
    ///
    /// For a lot of users, the system won't show the system-extension-blocked alert if there's a previous request
    /// to activate the extension.  You can see active requests in your console using command
    /// `systemextensionsctl list`.
    ///
    /// Proposed workaround: Just open system settings into the right section when we detect a previous
    /// activation request already exists.
    ///
    /// ## Tradeoffs
    ///
    /// Unfortunately we don't know if the previous request was sent out by the currently runing-instance of this App
    /// or if an activation request was made, and then the App was reopened.
    ///
    /// This means we don't know if we'll be notified when the previous activation request completes or fails.  Because we
    /// need to update our UI once the extension is allowed, we can't avoid sending a new activation request every time.
    ///
    /// For the users that don't see the alert come up more than once this should be invisible.  For users (like myself) that
    /// see the alert every single time, they'll see both the alert and system settings being opened automatically.
    ///
    private func workaroundToActivateBeforeSequoia() {
        if hasPendingActivationRequests() {
            openSystemSettingsSecurity()
        }
    }

    public func deactivate() async throws {
        try await SystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: extensionBundleID,
            manager: manager)
        .submit()
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
        task.arguments = ["-c", "$(which systemextensionsctl) list | $(which egrep) -c '(?:\(extensionBundleID)).+(?:activated waiting for user)+'"]

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

    private let request: OSSystemExtensionRequest
    private let manager: OSSystemExtensionManager
    private let waitingForUserApproval: (() -> Void)?
    private(set) var version: String?

    private var continuation: CheckedContinuation<Void, Error>?

    private init(request: OSSystemExtensionRequest, manager: OSSystemExtensionManager, waitingForUserApproval: (() -> Void)? = nil) {
        self.manager = manager
        self.request = request
        self.waitingForUserApproval = waitingForUserApproval

        super.init()
    }

    static func activationRequest(forExtensionWithIdentifier bundleId: String, manager: OSSystemExtensionManager, waitingForUserApproval: (() -> Void)?) -> Self {
        self.init(request: .activationRequest(forExtensionWithIdentifier: bundleId, queue: .global()), manager: manager, waitingForUserApproval: waitingForUserApproval)
    }

    static func deactivationRequest(forExtensionWithIdentifier bundleId: String, manager: OSSystemExtensionManager) -> Self {
        self.init(request: .deactivationRequest(forExtensionWithIdentifier: bundleId, queue: .global()), manager: manager)
    }

    /// Submit the request
    ///
    func submit() async throws {
        assert(continuation == nil, "Request can only be submitted once")

        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            request.delegate = self
            manager.submitRequest(request)
        }
    }

    private func updateVersion(to version: String) {
        self.version = version
    }

    private func updateVersionNumberIfMissing() {
        guard version == nil,
              let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return
        }

        var extensionVersion = versionString

        if let buildString = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String {
            extensionVersion = extensionVersion + "." + buildString
        }
    }
}

extension SystemExtensionRequest: OSSystemExtensionRequestDelegate {

    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {

        updateVersion(to: ext.bundleShortVersion + "." + ext.bundleVersion)
        return .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        waitingForUserApproval?()
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        switch result {
        case .completed:
            updateVersionNumberIfMissing()
            continuation?.resume()
            continuation = nil
        case .willCompleteAfterReboot:
            continuation?.resume(throwing: SystemExtensionRequestError.willActivateAfterReboot)
            continuation = nil
            return
        @unknown default:
            // Not much we can do about this, so we just let the owning app decide
            // what to do about this.
            continuation?.resume(throwing: SystemExtensionRequestError.unknownRequestResult)
            continuation = nil
            return
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

}
