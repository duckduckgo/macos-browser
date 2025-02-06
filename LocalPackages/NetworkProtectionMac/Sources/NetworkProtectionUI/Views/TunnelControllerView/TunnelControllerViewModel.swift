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
import NetworkProtectionProxy
import SwiftUI
import TipKit

@MainActor
public final class TunnelControllerViewModel: ObservableObject {
    public struct FormattedDataVolume: Equatable {
        public let dataSent: String
        public let dataReceived: String
    }

    /// The NetP service.
    ///
    private let tunnelController: TunnelController

    /// Whether the VPN is enabled
    /// This is determined based on the connection status, same as the iOS version
    ///
    public var isVPNEnabled: Bool {
        get {
            switch connectionStatus {
            case .connected, .connecting:
                return true
            default:
                return false
            }
        }
    }

    public var exclusionsFeatureEnabled: Bool {
        proxySettings.proxyAvailable
    }

    /// The type of extension that's being used for NetP
    ///
    @Published
    private(set) var onboardingStatus: OnboardingStatus = .completed

    var shouldFlipToggle: Bool {
        // The toggle is not flipped when we're asking to allow a system extension
        // because that step does not result in the tunnel being started.
        onboardingStatus != .isOnboarding(step: .userNeedsToAllowExtension)
    }

    /// The NetP onboarding status publisher
    ///
    private let onboardingStatusPublisher: OnboardingStatusPublisher

    /// The NetP status reporter
    ///
    private let statusReporter: NetworkProtectionStatusReporter

    private let vpnSettings: VPNSettings
    private let proxySettings: TransparentProxySettings
    private let locationFormatter: VPNLocationFormatting

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter
    }()

    private let uiActionHandler: VPNUIActionHandling

    // MARK: - Misc

    /// The `RunLoop` for the timer.
    ///
    private let runLoopMode: RunLoop.Mode?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization & Deinitialization

    public init(controller: TunnelController,
                onboardingStatusPublisher: OnboardingStatusPublisher,
                statusReporter: NetworkProtectionStatusReporter,
                runLoopMode: RunLoop.Mode? = nil,
                vpnSettings: VPNSettings,
                proxySettings: TransparentProxySettings,
                locationFormatter: VPNLocationFormatting,
                uiActionHandler: VPNUIActionHandling) {

        self.tunnelController = controller
        self.onboardingStatusPublisher = onboardingStatusPublisher
        self.statusReporter = statusReporter
        self.runLoopMode = runLoopMode
        self.vpnSettings = vpnSettings
        self.proxySettings = proxySettings
        self.locationFormatter = locationFormatter
        self.uiActionHandler = uiActionHandler

        connectionStatus = statusReporter.statusObserver.recentValue
        dnsSettings = vpnSettings.dnsSettings

        formattedDataVolume = statusReporter.dataVolumeObserver.recentValue.formatted(using: Self.byteCountFormatter)
        internalServerAddress = statusReporter.serverInfoObserver.recentValue.serverAddress
        internalServerAttributes = statusReporter.serverInfoObserver.recentValue.serverLocation
        internalServerLocation = internalServerAttributes?.serverLocation

        // Particularly useful when unit testing with an initial status of our choosing.
        refreshInternalIsRunning()

        subscribeToOnboardingStatusChanges()
        subscribeToStatusChanges()
        subscribeToServerInfoChanges()
        subscribeToDataVolumeUpdates()

        vpnSettings.dnsSettingsPublisher
            .assign(to: \.dnsSettings, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Subscriptions

    private func subscribeToOnboardingStatusChanges() {
        onboardingStatusPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.onboardingStatus, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToStatusChanges() {
        statusReporter.statusObserver.publisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionStatus, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToServerInfoChanges() {
        statusReporter.serverInfoObserver.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] serverInfo in

            guard let self else {
                return
            }

            Task { @MainActor in
                self.internalServerAddress = serverInfo.serverAddress
                self.internalServerAttributes = serverInfo.serverLocation
                self.internalServerLocation = self.internalServerAttributes?.serverLocation
            }
        }
            .store(in: &cancellables)
    }

    private func subscribeToDataVolumeUpdates() {
        statusReporter.dataVolumeObserver.publisher
            .map { $0.formatted(using: Self.byteCountFormatter) }
            .receive(on: DispatchQueue.main)
            .assign(to: \.formattedDataVolume, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    // MARK: - ON/OFF Toggle

    private func startTimer() {
        guard timer == nil else {
            return
        }

        refreshTimeLapsed()

        let newTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in

            guard let self else {
                return
            }

            Task { @MainActor in
                self.refreshTimeLapsed()
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

    private var previousConnectionStatus: NetworkProtection.ConnectionStatus = .default

    @MainActor
    @Published
    private var connectionStatus: NetworkProtection.ConnectionStatus {
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
    @MainActor
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
        case .switchingOn, .switchingOff:
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

    @MainActor
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
        case .snoozing:
            // Snooze mode is not supported on macOS, but fall back to the disconnected string to be safe.
            return UserText.networkProtectionStatusDisconnected
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
            return UserText.networkProtectionFormattedServerLocation(internalServerLocation)
        case .disconnecting:
            if case .connected = previousConnectionStatus {
                return UserText.networkProtectionFormattedServerLocation(internalServerLocation)
            } else {
                return UserText.networkProtectionServerLocationUnknown
            }
        default:
            return UserText.networkProtectionServerLocationUnknown
        }
    }

    @Published
    private var internalServerAttributes: NetworkProtectionServerInfo.ServerAttributes?

    @Published
    var dnsSettings: NetworkProtectionDNSSettings

    @Published
    var formattedDataVolume: FormattedDataVolume

    var wantsNearestLocation: Bool {
        guard case .nearest = vpnSettings.selectedLocation else { return false }
        return true
    }

    var emoji: String? {
        locationFormatter.emoji(for: internalServerAttributes?.country,
                                preferredLocation: vpnSettings.selectedLocation)
    }

    var plainLocation: String {
        locationFormatter.string(from: internalServerLocation,
                                 preferredLocation: vpnSettings.selectedLocation)
    }

    @available(macOS 12, *)
    func formattedLocation(colorScheme: ColorScheme) -> AttributedString {
        let opacity = colorScheme == .light ? Double(0.6) : Double(0.5)
        return locationFormatter.string(from: internalServerLocation,
                                        preferredLocation: vpnSettings.selectedLocation,
                                        locationTextColor: Color(.defaultText),
                                        preferredLocationTextColor: Color(.defaultText).opacity(opacity))
    }

    // MARK: - Toggling VPN

    /// Start the VPN.
    ///
    func startNetworkProtection() {
        if shouldFlipToggle {
            toggleTransition = .switchingOn(locallyInitiated: true)
        }

        Task { @MainActor in
            await tunnelController.start()
            refreshInternalIsRunning()
        }
    }

    /// Stop the VPN.
    ///
    func stopNetworkProtection() {
        toggleTransition = .switchingOff(locallyInitiated: true)

        Task { @MainActor in
            await tunnelController.stop()
            refreshInternalIsRunning()
        }
    }

    func showLocationSettings() {
        Task { @MainActor in
            await uiActionHandler.showVPNLocations()
        }
    }

#if !APPSTORE && !DEBUG
    func moveToApplications() {
        Task { @MainActor in
            await uiActionHandler.moveAppToApplications()
        }
    }
#endif
}

extension DataVolume {
    func formatted(using formatter: ByteCountFormatter) -> TunnelControllerViewModel.FormattedDataVolume {
        .init(dataSent: formatter.string(fromByteCount: bytesSent),
              dataReceived: formatter.string(fromByteCount: bytesReceived))
    }
}
