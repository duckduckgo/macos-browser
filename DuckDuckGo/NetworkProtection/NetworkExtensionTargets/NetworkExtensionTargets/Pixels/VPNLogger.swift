//
//  VPNLogger.swift
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
import NetworkProtection
// swiftlint:disable:next enforce_os_log_wrapper
import OSLog

/// Logger for the VPN
///
/// Since we'll want to ensure this adheres to our privacy standards, grouping the logging logic to be mostly
/// handled by a single class sounds like a good approach to be able to review what's being logged..
///
final class VPNLogger {
    typealias AttemptStep = PacketTunnelProvider.AttemptStep
    typealias ConnectionAttempt = PacketTunnelProvider.ConnectionAttempt
    typealias LogCallback = (OSLogType, OSLogMessage) -> Void

    private let log: LogCallback

    init(logCallback: @escaping LogCallback) {
        log = logCallback
    }

    convenience init() {
        let logger = Logger(.networkProtection)

        self.init { logType, message in
            logger.log(level: logType, message)
        }
    }

    func log(_ step: AttemptStep, named name: String, log: OSLog) {
        switch step {
        case .begin:
            log(.info, "🔵 \(name) attempt begins")
            os_log("🔵 %{public}@ attempt begins", log: log, type: .info, name)
        case .failure(let error):
            logCallback(.error, error.localizedDescription)
            Logger(subsystem: "asd", category: "asd").log("\(error.localizedDescription, privacy: .private)")
            os_log("🔴 %{public}@ attempt failed with error: %{public}@", log: log, type: .error, name, error.localizedDescription)
        case .success:
            os_log("🟢 %{public}@ attempt succeeded", log: log, type: .info, name)
        }
    }

    func log(_ step: ConnectionAttempt, log: OSLog) {
        switch step {
        case .connecting:
            os_log("🔵 Connection attempt detected", log: log, type: .info)
        case .failure:
            os_log("🔴 Connection attempt failed", log: log, type: .error)
        case .success:
            os_log("🟢 Connection attempt successful", log: log, type: .info)
        }
    }

    func log(_ step: FailureRecoveryStep, log: OSLog) {
        switch step {
        case .started:
            os_log("🔵 Failure Recovery attempt started", log: log, type: .info)
        case .failed(let error):
            os_log("🔴 Failure Recovery attempt failed with error: %{public}@", log: log, type: .error, error.localizedDescription)
        case .completed(let health):
            switch health {
            case .healthy:
                os_log("🟢 Failure Recovery attempt completed", log: log, type: .info)
            case .unhealthy:
                os_log("🔴 Failure Recovery attempt ended as unhealthy", log: log, type: .error)
            }
        }
    }

    func log(_ step: NetworkProtectionTunnelFailureMonitor.Result, log: OSLog) {
        switch step {
        case .failureDetected:
            os_log("🔴 Tunnel failure detected", log: log, type: .error)
        case .failureRecovered:
            os_log("🟢 Tunnel failure recovered", log: log, type: .info)
        case .networkPathChanged:
            os_log("🔵 Tunnel recovery detected path change", log: log, type: .info)
        }
    }
}
