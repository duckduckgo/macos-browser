//
//  NetworkProtectionLatencyReporter.swift
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

import Combine
import Foundation
import Common
import Network

protocol LatencyMeasurer: Sendable {
    func ping() async -> Result<Pinger.PingResult, Pinger.PingError>
}
extension Pinger: LatencyMeasurer {}

actor NetworkProtectionLatencyReporter {

    struct Configuration {
        let firstPingDelay: TimeInterval
        let pingInterval: TimeInterval

        let timeout: TimeInterval
        let waitForNextConnectionTypeQuery: TimeInterval

        init(firstPingDelay: TimeInterval = .minutes(15),
             pingInterval: TimeInterval = .hours(4),
             timeout: TimeInterval = .seconds(5),
             waitForNextConnectionTypeQuery: TimeInterval = .seconds(15)) {

            self.firstPingDelay = firstPingDelay
            self.pingInterval = pingInterval
            self.timeout = timeout
            self.waitForNextConnectionTypeQuery = waitForNextConnectionTypeQuery
        }

        static let `default` = Configuration()
    }

    private let configuration: Configuration
    private let networkPathMonitor: NWPathMonitor
    private var currentConnectionType: NetworkConnectionType?

    private nonisolated let getLogger: (@Sendable () -> OSLog)

    @MainActor
    private var task: Task<Never, Error>? {
        willSet {
            task?.cancel()
        }
    }

    @MainActor
    private(set) var currentIP: IPv4Address?
    @MainActor
    var isStarted: Bool {
        task?.isCancelled == false
    }

    typealias PingerFactory = @Sendable (IPv4Address, TimeInterval) -> LatencyMeasurer
    private let pingerFactory: PingerFactory

    init(configuration: Configuration = .default,
         log: @autoclosure @escaping (@Sendable () -> OSLog) = .disabled,
         pingerFactory: PingerFactory? = nil) {

        self.configuration = configuration
        self.getLogger = log
        self.pingerFactory = pingerFactory ?? { ip, timeout in
            Pinger(ip: ip, timeout: timeout, log: log())
        }

        let networkPathMonitor = NWPathMonitor()
        self.networkPathMonitor = networkPathMonitor

        networkPathMonitor.pathUpdateHandler = { [weak self] path in
            guard let connectionType = NetworkConnectionType(nwPath: path) else { return }
            Task { [weak self] in
                await self?.updateCurrentNetworkConnectionType(connectionType)
            }
        }
        networkPathMonitor.start(queue: .global())
    }

    @MainActor
    func start(ip: IPv4Address, reportCallback: @escaping @Sendable (TimeInterval, NetworkConnectionType) -> Void) {
        let log = { @Sendable [weak self] in self?.getLogger() ?? .disabled }
        let pinger = pingerFactory(ip, configuration.timeout)
        self.currentIP = ip

        // run periodic latency measurement with initial delay and following interval
        task = Task.periodic(delay: configuration.firstPingDelay, interval: configuration.pingInterval) { [weak self, configuration] in
            guard let self else { return }
            do {
                // poll for current connection type (cellular/wifi/eth) set by NWPathMonitor
                let networkPath: NetworkConnectionType = try await {
                    while true {
                        if let currentConnectionType = await self.currentConnectionType {
                            return currentConnectionType
                        }
                        try await Task.sleep(interval: configuration.waitForNextConnectionTypeQuery)
                    }
                }()

                // ping the host
                let latency = try await pinger.ping().get().time

                // report
                reportCallback(latency, networkPath)

            } catch {
                os_log("ping failed: %s", log: log(), type: .error, error.localizedDescription)
            }
        }
    }

    @MainActor
    func stop() {
        task = nil
    }

    private func updateCurrentNetworkConnectionType(_ connectionType: NetworkConnectionType) {
        self.currentConnectionType = connectionType
    }

    deinit {
        task?.cancel()
        networkPathMonitor.cancel()
    }

}
