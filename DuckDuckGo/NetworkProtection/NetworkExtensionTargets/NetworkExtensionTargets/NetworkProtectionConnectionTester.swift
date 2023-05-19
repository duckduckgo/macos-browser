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

    enum TesterError: Error {
        case couldNotFindInterface(named: String)
    }

    /// Provides a simple mechanism to synchronize an `isRunning` flag for the tester to know if it needs to interrupt its operation.
    /// The reason why this is necessary is that the tester may be stopped while the connection tests are already executing, in a bit
    /// of a race condition which could result in the tester returning results when it's already stopped.
    ///
    private actor TimerRunCoordinator {
        private(set) var isRunning = false

        func start() {
            isRunning = true
        }

        func stop() {
            isRunning = false
        }
    }

    static let connectionTestQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionConnectionTester.connectionTestQueue")
    static let monitorQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionConnectionTester.monitorQueue")
    static let endpoint = NWEndpoint.hostPort(host: .name("www.duckduckgo.com", nil), port: .https)

    private var timer: DispatchSourceTimer?
    private let timerRunCoordinator = TimerRunCoordinator()

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
    private let intervalBetweenTests: TimeInterval = .seconds(15)

    /// The time we'll waitfor the TCP connection to fail.  This should always be lower than `intervalBetweenTests`.
    ///
    private static let connectionTimeout: TimeInterval = .seconds(5)

    // MARK: - Logging

    private let log: OSLog

    // MARK: - Test result handling

    private var failureCount = 0
    private let resultHandler: @MainActor (Result) -> Void

    // MARK: - Init & deinit

    init(timerQueue: DispatchQueue, log: OSLog, resultHandler: @escaping @MainActor (Result) -> Void) {
        self.timerQueue = timerQueue
        self.log = log
        self.resultHandler = resultHandler
    }

    deinit {
        cancelTimerImmediately()
    }

    // MARK: - Starting & Stopping the tester

    func start(tunnelIfName: String) async throws {
        guard await !timerRunCoordinator.isRunning else {
            os_log("Will not start the connection tester as it's already running", log: log, type: .debug)
            return
        }

        os_log("🟢 Starting connection tester", log: log, type: .debug)
        let tunnelInterface = try await networkInterface(forInterfaceNamed: tunnelIfName)
        self.tunnelInterface = tunnelInterface

        await scheduleTimer()
    }

    func stop() async {
        os_log("🔴 Stopping connection tester", log: log, type: .debug)
        await stopScheduledTimer()
    }

    /// Run the test right now and schedule the next one regularly.
    /// 
    func testImmediately() async {
        await stopScheduledTimer()
        testConnection()
        await scheduleTimer()
    }

    // MARK: - Obtaining the interface

    private func networkInterface(forInterfaceNamed interfaceName: String) async throws -> NWInterface {
        try await withCheckedThrowingContinuation { continuation in
            let monitor = NWPathMonitor()

            monitor.pathUpdateHandler = { path in
                os_log("All interfaces: %{public}@", log: self.log, type: .debug, String(describing: path.availableInterfaces))

                guard let tunnelInterface = path.availableInterfaces.first(where: { $0.name == interfaceName }) else {
                    os_log("Could not find VPN interface %{public}@", log: self.log, type: .error, interfaceName)
                    monitor.cancel()
                    monitor.pathUpdateHandler = nil

                    continuation.resume(throwing: TesterError.couldNotFindInterface(named: interfaceName))
                    return
                }

                monitor.cancel()
                monitor.pathUpdateHandler = nil

                continuation.resume(returning: tunnelInterface)
            }

            monitor.start(queue: Self.monitorQueue)
        }
    }

    // MARK: - Timer scheduling

    private func scheduleTimer() async {
        await stopScheduledTimer()

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + self.intervalBetweenTests, repeating: self.intervalBetweenTests)
        timer.setEventHandler { [weak self] in
            self?.testConnection()
        }

        timer.setCancelHandler { [weak self] in
            self?.timer = nil
        }

        await timerRunCoordinator.start()
        timer.resume()

        self.timer = timer
    }

    private func stopScheduledTimer() async {
        await timerRunCoordinator.stop()

        cancelTimerImmediately()
    }

    private func cancelTimerImmediately() {
        guard let timer = timer else {
            return
        }

        if !timer.isCancelled {
            timer.cancel()
        }

        self.timer = nil
    }

    // MARK: - Testing the connection

    func testConnection() {
        guard let tunnelInterface = tunnelInterface else {
            os_log("No interface to test!", log: log, type: .error)
            return
        }

        os_log("Testing connection...", log: log, type: .debug)

        let vpnParameters = NWParameters.tcp
        vpnParameters.requiredInterface = tunnelInterface

        let localParameters = NWParameters.tcp
        localParameters.prohibitedInterfaces = [tunnelInterface]

        Task {
            // This is a bit ugly, but it's a quick way to run the tests in parallel without a task group.
            async let vpnConnected = Self.testConnection(name: "VPN", parameters: vpnParameters)
            async let localConnected = Self.testConnection(name: "Local", parameters: localParameters)
            let vpnIsConnected = await vpnConnected
            let localIsConnected = await localConnected

            let onlyVPNIsDown = !vpnIsConnected && localIsConnected

            // After completing the conection tests we check if the tester is still supposed to be running
            // to avoid giving results when it should not be running.
            guard await timerRunCoordinator.isRunning else {
                os_log("Tester skipped returning results as it was stopped while running the tests", log: log, type: .info)
                return
            }

            if onlyVPNIsDown {
                os_log("👎", log: log, type: .debug)
                await handleDisconnected()
            } else {
                os_log("👍", log: log, type: .debug)
                await handleConnected()
            }
        }
    }

    private static func testConnection(name: String, parameters: NWParameters) async -> Bool {
        let connection = NWConnection(to: Self.endpoint, using: parameters)
        var didConnect = false

        connection.stateUpdateHandler = { state in
            if case .ready = state {
                didConnect = true
            }
        }

        connection.start(queue: Self.connectionTestQueue)
        try? await Task.sleep(interval: connectionTimeout)
        connection.cancel()

        return didConnect
    }

    // MARK: - Result handling

    @MainActor
    private func handleConnected() {
        if failureCount == 0 {
            resultHandler(.connected)
        } else if failureCount > 0 {
            failureCount = 0

            resultHandler(.reconnected)
        }
    }

    @MainActor
    private func handleDisconnected() {
        failureCount += 1
        resultHandler(.disconnected(failureCount: failureCount))
    }
}
