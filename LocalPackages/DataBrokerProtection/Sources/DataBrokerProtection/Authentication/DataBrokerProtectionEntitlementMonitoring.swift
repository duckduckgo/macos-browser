//
//  DataBrokerProtectionEntitlementMonitoring.swift
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

protocol DataBrokerProtectionEntitlementMonitoring {
    func start(checkEntitlementFunction: @escaping () async throws -> Bool, interval: TimeInterval, callback: @escaping (DataBrokerProtectionEntitlementMonitorResult) -> Void)
    func stop()
}

public enum DataBrokerProtectionEntitlementMonitorResult {
    case enabled
    case disabled
    case error
}

final class DataBrokerProtectionEntitlementMonitor: DataBrokerProtectionEntitlementMonitoring {
    private var timer: Timer?

    func start(checkEntitlementFunction: @escaping () async throws -> Bool, interval: TimeInterval, callback: @escaping (DataBrokerProtectionEntitlementMonitorResult) -> Void) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                do {
                    switch try await checkEntitlementFunction() {
                    case true:
                        callback(.enabled)
                    case false:
                        callback(.disabled)
                    }
                } catch {
                    callback(.error)
                }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
