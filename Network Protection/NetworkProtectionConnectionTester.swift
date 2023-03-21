//
//  NetworkProtectionConnectionTester.swift
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

import Foundation
import Network
import NetworkExtension
import os

/// This class takes care of testing whether the Network Protection connection is working or not.  Results are handled by
/// an injected object that implements ``NetworkProtectionConnectionTestResultsHandler``.
///
/// In order to test that the connection is working, this class test creating a TCP connection to "www.duckduckgo.com" using
/// the HTTPs port (443) both with and without using the tunnel.  The tunnel connection will be considered to be disconnected
/// whenever the regular connection works fine but the tunnel connection doesn't.
///
final class NetworkProtectionConnectionTester {
    enum Result {
        case connected
        case reconnected
        case disconnected(failureCount: Int)
    }

    static let connectionTestQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionConnectionTester.connectionTestQueue")
    static let monitorQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionConnectionTester.monitorQueue")
    static let endpoint = NWEndpoint.hostPort(host: .name("www.duckduckgo.com", nil), port: .https)

    private var timer: DispatchSourceTimer?

    // MARK: - Dispatch Queue

    private let timerQueue: DispatchQueue

    // MARK: - Tunnel Data

    /// This monitor will be used to retrieve the tunnel's NWInterface
    ///
    private var monitor: NWPathMonitor?

    /// The tunnel's interface we'll use to be able to test a connection going through, and a connection going out of the tunnel.
    ///
    private var tunnelInterface: NWInterface?

    // MARK: - Timing Parameters

    /// The interval of time between the start of each TCP connection test.
    ///
    private let intervalBetweenTests = TimeInterval(15)

    /// The time we'll waitfor the TCP connection to fail.  This should always be lower than `intervalBetweenTests`.
    ///
    private let connectionTimeout = 5

    // MARK: - Test result handling

    private var failureCount = 0
    private let resultHandler: (Result) -> Void

    // MARK: - Init & deinit

    init(timerQueue: DispatchQueue, resultHandler: @escaping (Result) -> Void) {
        self.timerQueue = timerQueue
        self.resultHandler = resultHandler
    }

    deinit {
        stop()
    }

    // MARK: - Starting & Stopping the tester

    func start(tunnelIfName: String) {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else {
                return
            }

            os_log("🔵 All interfaces: %{public}@", log: .networkProtection, type: .info, String(describing: path.availableInterfaces))

            guard let tunnelInterface = path.availableInterfaces.first(where: { $0.name == tunnelIfName }) else {
                os_log("🔵 Could not find VPN interface %{public}@", log: .networkProtection, type: .error, tunnelIfName)
                self.monitor?.cancel()
                self.monitor = nil
                return
            }

            self.tunnelInterface = tunnelInterface
            self.monitor?.cancel()
            self.monitor = nil

            os_log("🔵 Scheduling timer", log: .networkProtection, type: .info)
            self.scheduleTimer()
        }

        os_log("🔵 Starting monitor", log: .networkProtection, type: .error)
        monitor.start(queue: Self.monitorQueue)
        self.monitor = monitor
    }

    func stop() {
        stopScheduledTimer()
    }

    /// Run the test right now and schedule the next one regularly.
    /// 
    func testImmediately() {
        stopScheduledTimer()
        testConnection()
        scheduleTimer()
    }

    // MARK: - Timer scheduling

    private func scheduleTimer() {
        stopScheduledTimer()

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + self.intervalBetweenTests, repeating: self.intervalBetweenTests)
        timer.setEventHandler { [weak self] in
            self?.testConnection()
        }
        timer.resume()

        self.timer = timer
    }

    private func stopScheduledTimer() {
        if let timer = timer {
            if !timer.isCancelled {
                timer.cancel()
            }

            self.timer = nil
        }
    }

    // MARK: - Testing the connection

    func testConnection() {
        guard let tunnelInterface = tunnelInterface else {
            os_log("🔵 No interface to test!", log: .networkProtection, type: .error)
            return
        }

        os_log("🔵 Testing connection", log: .networkProtection, type: .info)

        let vpnParameters = NWParameters.tcp
        vpnParameters.requiredInterface = tunnelInterface

        let localParameters = NWParameters.tcp
        localParameters.prohibitedInterfaces = [tunnelInterface]

        Task {
            // This is a bit ugly, but it's a quick way to run the tests in parallel without a task group.
            async let vpnConnected = testConnection(name: "VPN", parameters: vpnParameters)
            async let localConnected = testConnection(name: "Local", parameters: localParameters)
            let vpnIsConnected = await vpnConnected
            let localIsConnected = await localConnected

            let onlyVPNIsDown = !vpnIsConnected && localIsConnected

            if onlyVPNIsDown {
                os_log("🔵 👎", log: .networkProtection, type: .info)
                handleDisconnected()
            } else {
                os_log("🔵 👍", log: .networkProtection, type: .info)
                handleConnected()
            }
        }
    }

    private func testConnection(name: String, parameters: NWParameters) async -> Bool {
        let connection = NWConnection(to: Self.endpoint, using: parameters)
        var didConnect = false

        connection.stateUpdateHandler = { state in
            if case .ready = state {
                didConnect = true
            }
        }

        connection.start(queue: Self.connectionTestQueue)
        try? await Task.sleep(nanoseconds: UInt64(connectionTimeout) * NSEC_PER_SEC)
        connection.cancel()

        return didConnect
    }

    // MARK: - Result handling

    private func handleConnected() {
        if failureCount == 0 {
            resultHandler(.connected)
        } else if failureCount > 0 {
            failureCount = 0

            resultHandler(.reconnected)
        }
    }

    private func handleDisconnected() {
        failureCount += 1
        resultHandler(.disconnected(failureCount: failureCount))
    }
}
