//
//  TunnelControllerViewModel.swift
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
import NetworkProtection
import SwiftUI

@MainActor
public final class TunnelControllerViewModel: ObservableObject {

    /// The NetP service.
    ///
    private let tunnelController: TunnelController

    /// The NetP status reporter
    ///
    private let statusReporter: NetworkProtectionStatusReporter

    // MARK: - Misc

    /// The `RunLoop` for the timer.
    ///
    private let runLoopMode: RunLoop.Mode?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dispatch Queues

    private static let statusDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionStatusView.statusDispatchQueue", qos: .userInteractive)
    private static let connectivityIssuesDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionStatusView.connectivityIssuesDispatchQueue", qos: .userInteractive)
    private static let serverInfoDispatchQueue = DispatchQueue(label: "com.duckduckgo.NetworkProtectionStatusView.serverInfoDispatchQueue", qos: .userInteractive)

    // MARK: - Feature Image

    var mainImageAsset: NetworkProtectionAsset {
        switch connectionStatus {
        case .connected:
            return .vpnEnabledImage
        case .disconnecting:
            if case .connected = previousConnectionStatus {
                return .vpnEnabledImage
            } else {
                return .vpnDisabledImage
            }
        default:
            return .vpnDisabledImage
        }
    }

    // MARK: - Initialization & Deinitialization

    public init(controller: TunnelController,
                statusReporter: NetworkProtectionStatusReporter,
                runLoopMode: RunLoop.Mode? = nil) {

        self.tunnelController = controller
        self.statusReporter = statusReporter
        self.runLoopMode = runLoopMode

        connectionStatus = statusReporter.statusObserver.recentValue
        internalServerAddress = statusReporter.serverInfoObserver.recentValue.serverAddress
        internalServerLocation = statusReporter.serverInfoObserver.recentValue.serverLocation

        // Particularly useful when unit testing with an initial status of our choosing.
        refreshInternalIsRunning()

        subscribeToStatusChanges()
        subscribeToServerInfoChanges()
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Subscriptions

    private func subscribeToStatusChanges() {
        statusReporter.statusObserver.publisher
            .subscribe(on: Self.statusDispatchQueue)
            .sink { [weak self] status in

            guard let self else {
                return
            }

            Task { @MainActor in
                self.connectionStatus = status
            }
        }
            .store(in: &cancellables)
    }

    private func subscribeToServerInfoChanges() {
        statusReporter.serverInfoObserver.publisher
            .subscribe(on: Self.serverInfoDispatchQueue)
            .sink { [weak self] serverInfo in

            guard let self else {
                return
            }

            Task { @MainActor in
                self.internalServerAddress = serverInfo.serverAddress
                self.internalServerLocation = serverInfo.serverLocation
            }
        }
            .store(in: &cancellables)
    }

    // MARK: - ON/OFF Toggle

    private func startTimer() {
        guard timer == nil else {
            return
        }

        refreshTimeLapsed()
        let call = refreshTimeLapsed

        let newTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                call()
            }
        }

        timer = newTimer

        if let runLoopMode = runLoopMode {
            RunLoop.current.add(newTimer, forMode: runLoopMode)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Whether NetP is actually running.
    ///
    @Published
    private var internalIsRunning = false {
        didSet {
            if internalIsRunning {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }

    @MainActor
    private func refreshInternalIsRunning() {
        switch connectionStatus {
        case .connected, .connecting, .reasserting:
            guard internalIsRunning == false else {
                return
            }

            internalIsRunning = true
        case .disconnected, .disconnecting:
            guard internalIsRunning == true else {
                return
            }

            internalIsRunning = false
        default:
            break
        }
    }

    /// Convenience binding to be able to both query and toggle NetP.
    ///
    @MainActor
    var isToggleOn: Binding<Bool> {
        .init {
            switch self.toggleTransition {
            case .idle:
                break
            case .switchingOn:
                return true
            case .switchingOff:
                return false
            }

            return self.internalIsRunning
        } set: { newValue in
            guard newValue != self.internalIsRunning else {
                return
            }

            self.internalIsRunning = newValue

            if newValue {
                self.startNetworkProtection()
            } else {
                self.stopNetworkProtection()
            }
        }
    }

    // MARK: - Status & health

    private weak var timer: Timer?

    private var previousConnectionStatus: NetworkProtection.ConnectionStatus = .disconnected

    @MainActor
    @Published
    private var connectionStatus: NetworkProtection.ConnectionStatus = .disconnected {
        didSet {
            detectAndRefreshExternalToggleSwitching()
            previousConnectionStatus = oldValue
            refreshInternalIsRunning()
            refreshTimeLapsed()
        }
    }

    /// This method serves as a simple mechanism to detect when the toggle is controlled by the agent app, or by another
    /// external event causing the tunnel to start or stop, so we can disable the toggle as it's transitioning..
    ///
    private func detectAndRefreshExternalToggleSwitching() {
        switch toggleTransition {
        case .idle:
            // When the toggle transition is idle, if the status changes to connecting or disconnecting
            // it means the tunnel is being controlled from elsewhere.
            if connectionStatus == .connecting {
                toggleTransition = .switchingOn(locallyInitiated: false)
            } else if connectionStatus == .disconnecting {
                toggleTransition = .switchingOff(locallyInitiated: false)
            }
        case .switchingOn(let locallyInitiated), .switchingOff(let locallyInitiated):
            guard !locallyInitiated else { break }

            if connectionStatus == .connecting {
                toggleTransition = .switchingOn(locallyInitiated: false)
            } else if connectionStatus == .disconnecting {
                toggleTransition = .switchingOff(locallyInitiated: false)
            } else {
                toggleTransition = .idle
            }
        }
    }

    // MARK: - Connection Status: Toggle State

    @frozen
    enum ToggleTransition: Equatable {
        case idle
        case switchingOn(locallyInitiated: Bool)
        case switchingOff(locallyInitiated: Bool)
    }

    /// Specifies a transition the toggle is undergoing, which will make sure the toggle stays in a position (either ON or OFF)
    /// and ignores intermediate status updates until the transition completes and this is set back to .idle.
    @Published
    private(set) var toggleTransition = ToggleTransition.idle

    /// The toggle is disabled while transitioning due to user interaction.
    ///
    var isToggleDisabled: Bool {
        if case .idle = toggleTransition {
            return false
        }

        return true
    }

    // MARK: - Connection Status: Timer

    /// The description for the current connection status.
    /// When the status is `connected` this description will also show the time lapsed since connection.
    ///
    @Published var timeLapsed = UserText.networkProtectionStatusViewTimerZero

    private func refreshTimeLapsed() {
        switch connectionStatus {
        case .connected(let connectedDate):
            timeLapsed = timeLapsedString(since: connectedDate)
        case .disconnecting:
            timeLapsed = UserText.networkProtectionStatusViewTimerZero
        default:
            timeLapsed = UserText.networkProtectionStatusViewTimerZero
        }
    }

    /// The description for the current connection status.
    /// When the status is `connected` this description will also show the time lapsed since connection.
    ///
    var connectionStatusDescription: String {
        // If the user is toggling NetP ON or OFF we'll respect the toggle state
        // until it's idle again
        switch toggleTransition {
        case .idle:
            break
        case .switchingOn:
            return UserText.networkProtectionStatusConnecting
        case .switchingOff:
            return UserText.networkProtectionStatusDisconnecting
        }

        switch connectionStatus {
        case .connected:
            return "\(UserText.networkProtectionStatusConnected) · \(timeLapsed)"
        case .connecting, .reasserting:
            return UserText.networkProtectionStatusConnecting
        case .disconnected, .notConfigured:
            return UserText.networkProtectionStatusDisconnected
        case .disconnecting:
            return UserText.networkProtectionStatusDisconnecting
        }
    }

    private func timeLapsedString(since date: Date) -> String {
        let secondsLapsed = Date().timeIntervalSince(date)

        let hours   = Int(secondsLapsed) / 3600
        let minutes = Int(secondsLapsed) / 60 % 60
        let seconds = Int(secondsLapsed) % 60

        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }

    /// The feature status (ON/OFF) right below the main icon.
    ///
    var featureStatusDescription: String {
        switch connectionStatus {
        case .connected, .disconnecting:
            return UserText.networkProtectionStatusViewFeatureOn
        default:
            return UserText.networkProtectionStatusViewFeatureOff
        }
    }

    // MARK: - Server Information

    var showServerDetails: Bool {
        switch connectionStatus {
        case .connected:
            return true
        case .disconnecting:
            if case .connected = previousConnectionStatus {
                return true
            } else {
                return false
            }
        default:
            return false
        }
    }

    @Published
    private var internalServerAddress: String?

    var serverAddress: String {
        guard let internalServerAddress = internalServerAddress else {
            return UserText.networkProtectionServerAddressUnknown
        }

        switch connectionStatus {
        case .connected:
            return internalServerAddress
        case .disconnecting:
            if case .connected = previousConnectionStatus {
                return internalServerAddress
            } else {
                return UserText.networkProtectionServerAddressUnknown
            }
        default:
            return UserText.networkProtectionServerAddressUnknown
        }
    }

    @Published
    var internalServerLocation: String?

    var serverLocation: String {
        guard let internalServerLocation = internalServerLocation else {
            return UserText.networkProtectionServerLocationUnknown
        }

        switch connectionStatus {
        case .connected:
            return internalServerLocation
        case .disconnecting:
            if case .connected = previousConnectionStatus {
                return internalServerLocation
            } else {
                return UserText.networkProtectionServerLocationUnknown
            }
        default:
            return UserText.networkProtectionServerLocationUnknown
        }
    }

    // MARK: - Toggling Network Protection

    /// Start network protection.
    ///
    func startNetworkProtection() {
        toggleTransition = .switchingOn(locallyInitiated: true)

        Task { @MainActor in
            await tunnelController.start()

            toggleTransition = .idle
            refreshInternalIsRunning()
        }
    }

    /// Stop network protection.
    ///
    func stopNetworkProtection() {
        toggleTransition = .switchingOff(locallyInitiated: true)

        Task { @MainActor in
            await tunnelController.stop()
            toggleTransition = .idle
            refreshInternalIsRunning()
        }
    }
}
