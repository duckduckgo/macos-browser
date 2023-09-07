//
//  LoginItem.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import AppKit
import os.log // swiftlint:disable:this enforce_os_log_wrapper
import Foundation
import ServiceManagement

/// Takes care of enabling and disabling a login item.
///
public struct LoginItem: Equatable {

    let agentBundleID: String
    let url: URL
    private let log: OSLog

    public var isRunning: Bool {
        !runningApplications.isEmpty
    }

    private var runningApplications: [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: agentBundleID)
    }

    public enum Status {
        case notRegistered
        case enabled
        case requiresApproval
        case notFound

        public var isEnabled: Bool {
            self == .enabled
        }

        @available(macOS 13.0, *)
        public init(_ status: SMAppService.Status) {
            switch status {
            case .notRegistered: self = .notRegistered
            case .enabled: self = .enabled
            case .requiresApproval: self = .requiresApproval
            case .notFound: self = .notFound
            @unknown default: self = .notFound
            }
        }
    }

    public var status: Status {
        guard #available(macOS 13.0, *) else {
            guard let job = ServiceManagement.copyAllJobDictionaries(kSMDomainUserLaunchd).first(where: {
                $0["Label"] as? String == agentBundleID
            }) else { return .notRegistered }

            os_log("🟢 found login item job: %{public}@", log: log, job.debugDescription)
            return job["OnDemand"] as? Bool == true ? .enabled : .requiresApproval
        }
        return Status(SMAppService.loginItem(identifier: agentBundleID).status)
    }

    public init(bundleId: String, url: URL, log: OSLog) {
        self.agentBundleID = bundleId
        self.url = url
        self.log = log
    }

    public func enable() throws {
        os_log("🟢 registering login item %{public}@", log: log, self.debugDescription)

        if #available(macOS 13.0, *) {
            try SMAppService.loginItem(identifier: agentBundleID).register()
        } else {
            SMLoginItemSetEnabled(agentBundleID as CFString, true)
        }
    }

    public func disable() throws {
        os_log("🟢 unregistering login item %{public}@", log: log, self.debugDescription)

        if #available(macOS 13.0, *) {
            try SMAppService.loginItem(identifier: agentBundleID).unregister()
        } else {
            SMLoginItemSetEnabled(agentBundleID as CFString, false)
        }
        stop()
    }

    /// Restarts a login item.
    ///
    /// This call will only enable the login item if it was enabled to begin with.
    ///
    public func restart() throws {
        guard [.enabled, .requiresApproval].contains(status) else {
            os_log("🟢 restart not needed for login item %{public}@", log: log, self.debugDescription)
            return
        }
        try? disable()
        try enable()
    }

    public func launch() async throws {
        os_log("🟢 launching login item %{public}@", log: log, self.debugDescription)
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    private func stop() {
        let runningApplications = runningApplications
        os_log("🟢 stopping %{public}@", log: log, runningApplications.map { $0.processIdentifier }.description)
        runningApplications.forEach { $0.terminate() }
    }

}

extension LoginItem: CustomDebugStringConvertible {

    public var debugDescription: String {
        "<LoginItem \(agentBundleID) isEnabled: \(status) isRunning: \(isRunning)>"
    }

}

private protocol ServiceManagementProtocol {
    func copyAllJobDictionaries(_ domain: CFString!) -> [[String: Any]]
    var errorDomain: String { get }
}
private struct SM: ServiceManagementProtocol {

    // suppress SMCopyAllJobDictionaries deprecation warning
    @available(macOS, introduced: 10.6, deprecated: 10.10)
    func copyAllJobDictionaries(_ domain: CFString!) -> [[String: Any]] {
        SMCopyAllJobDictionaries(domain).takeRetainedValue() as? [[String: Any]] ?? []
    }

    @available(macOS, introduced: 10.6, deprecated: 10.10)
    var errorDomain: String {
        if #available(macOS 13.0, *) {
            return "SMAppServiceErrorDomain"
        } else {
            return kSMErrorDomainLaunchd as String
        }
    }

}

private var ServiceManagement: ServiceManagementProtocol { SM() } // swiftlint:disable:this identifier_name
