//
//  VPNTipsModel.swift
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

import AppKit
import Combine
import Common
import NetworkProtection
import NetworkProtectionProxy
import os.log
import TipKit
import PixelKit
import VPNPixels

@MainActor
public final class VPNTipsModel: ObservableObject {

    static let imageSize = CGSize(width: 32, height: 32)

    @Published
    private(set) var activeSiteInfo: ActiveSiteInfo? {
        didSet {
            guard #available(macOS 14.0, *) else {
                return
            }

            handleActiveSiteInfoChanged(newValue: activeSiteInfo)
        }
    }

    @Published
    private(set) var connectionStatus: ConnectionStatus {
        didSet {
            guard #available(macOS 14.0, *) else {
                return
            }

            handleConnectionStatusChanged(oldValue: oldValue, newValue: connectionStatus)
        }
    }

    @Published
    private var featureFlag: Bool

    private let isMenuApp: Bool
    private let vpnSettings: VPNSettings
    private let proxySettings: TransparentProxySettings
    private let logger: Logger
    private var cancellables = Set<AnyCancellable>()

    public init(featureFlagPublisher: CurrentValuePublisher<Bool, Never>,
                statusObserver: ConnectionStatusObserver,
                activeSitePublisher: CurrentValuePublisher<ActiveSiteInfo?, Never>,
                forMenuApp isMenuApp: Bool,
                vpnSettings: VPNSettings,
                proxySettings: TransparentProxySettings,
                logger: Logger) {

        self.activeSiteInfo = activeSitePublisher.value
        self.connectionStatus = statusObserver.recentValue
        self.featureFlag = featureFlagPublisher.value
        self.isMenuApp = isMenuApp
        self.logger = logger
        self.vpnSettings = vpnSettings
        self.proxySettings = proxySettings

        guard !isMenuApp else {
            return
        }

        if #available(macOS 14.0, *) {
            handleActiveSiteInfoChanged(newValue: activeSiteInfo)
            handleConnectionStatusChanged(oldValue: connectionStatus, newValue: connectionStatus)

            subscribeToConnectionStatusChanges(statusObserver)
            subscribeToFeatureFlagChanges(featureFlagPublisher)
            subscribeToActiveSiteChanges(activeSitePublisher)
        }
    }

    deinit {
        geoswitchingStatusUpdateTask?.cancel()
        geoswitchingStatusUpdateTask = nil
    }

    var canShowTips: Bool {
        !isMenuApp && featureFlag
    }

    // MARK: - Subscriptions

    @available(macOS 14.0, *)
    private func subscribeToFeatureFlagChanges(_ publisher: CurrentValuePublisher<Bool, Never>) {
        publisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: \.featureFlag, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    @available(macOS 14.0, *)
    private func subscribeToConnectionStatusChanges(_ statusObserver: ConnectionStatusObserver) {
        statusObserver.publisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionStatus, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    @available(macOS 14.0, *)
    private func subscribeToActiveSiteChanges(_ publisher: CurrentValuePublisher<ActiveSiteInfo?, Never>) {

        publisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: \.activeSiteInfo, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    // MARK: - Tips

    let autoconnectTip = VPNAutoconnectTip()
    let domainExclusionsTip = VPNDomainExclusionsTip()
    let geoswitchingTip = VPNGeoswitchingTip()

    var geoswitchingStatusUpdateTask: Task<Void, Never>?

    @available(macOS 14.0, *)
    var canShowDomainExclusionsTip: Bool {
        guard canShowTips else {
            return false
        }

        // If the proxy is available, we can show this tip after the geoswitchin tip
        // Otherwise we can't show this tip
        if proxySettings.proxyAvailable,
           case .invalidated = geoswitchingTip.status {

            return true
        }

        return false
    }

    @available(macOS 14.0, *)
    var canShowAutoconnectTip: Bool {
        guard canShowTips else {
            return false
        }

        // If the proxy is available, we need to wait until the domain exclusions tip was shown.
        // If the proxy is not available, we can show this tip after the geoswitchin tip
        if proxySettings.proxyAvailable,
           case .invalidated = domainExclusionsTip.status {

            return true
        } else if !proxySettings.proxyAvailable,
           case .invalidated = geoswitchingTip.status {

            return true
        }

        return false
    }

    // MARK: - Tip Action handling

    @available(macOS 14.0, *)
    func autoconnectTipActionHandler(_ action: Tip.Action) {
        if action.id == VPNAutoconnectTip.ActionIdentifiers.enable.rawValue {
            vpnSettings.connectOnLogin = true

            autoconnectTip.invalidate(reason: .actionPerformed)
        }
    }

    // MARK: - Handle Refreshing

    @available(macOS 14.0, *)
    private func handleActiveSiteInfoChanged(newValue: ActiveSiteInfo?) {
        guard !isMenuApp else { return }
        return VPNDomainExclusionsTip.hasActiveSite = (activeSiteInfo != nil)
    }

    @available(macOS 14.0, *)
    private func handleConnectionStatusChanged(oldValue: ConnectionStatus, newValue: ConnectionStatus) {
        guard !isMenuApp else { return }
        switch newValue {
        case .connected:
            if case oldValue = .connecting {
                handleTipDistanceConditionsCheckpoint()
            }

            VPNGeoswitchingTip.vpnEnabledOnce = true
            VPNAutoconnectTip.vpnEnabled = true
            VPNDomainExclusionsTip.vpnEnabled = true
        default:
            VPNAutoconnectTip.vpnEnabled = false
            VPNDomainExclusionsTip.vpnEnabled = false
        }
    }

    @available(macOS 14.0, *)
    private func handleTipDistanceConditionsCheckpoint() {
        if case .invalidated = geoswitchingTip.status {
            VPNDomainExclusionsTip.isDistancedFromPreviousTip = true
        }

        if case .invalidated = domainExclusionsTip.status {
            VPNAutoconnectTip.isDistancedFromPreviousTip = true
        }
    }

    // MARK: - UI Events

    @available(macOS 14.0, *)
    func handleAutoconnectTipInvalidated(_ reason: Tip.InvalidationReason) {
        switch reason {
        case .actionPerformed:
            PixelKit.fire(VPNTipPixel.autoconnectTip(step: .actioned))
        default:
            PixelKit.fire(VPNTipPixel.autoconnectTip(step: .dismissed))
        }
    }

    @available(macOS 14.0, *)
    func handleDomainExclusionTipInvalidated(_ reason: Tip.InvalidationReason) {
        switch reason {
        case .actionPerformed:
            PixelKit.fire(VPNTipPixel.domainExclusionsTip(step: .actioned))
        default:
            PixelKit.fire(VPNTipPixel.domainExclusionsTip(step: .dismissed))
        }
    }

    @available(macOS 14.0, *)
    func handleGeoswitchingTipInvalidated(_ reason: Tip.InvalidationReason) {
        switch reason {
        case .actionPerformed:
            PixelKit.fire(VPNTipPixel.geoswitchingTip(step: .actioned))
        default:
            PixelKit.fire(VPNTipPixel.geoswitchingTip(step: .dismissed))
        }
    }

    @available(macOS 14.0, *)
    func handleLocationsShown() {
        guard !isMenuApp else { return }
        geoswitchingTip.invalidate(reason: .actionPerformed)
    }

    @available(macOS 14.0, *)
    func handleSiteExcluded() {
        guard !isMenuApp else { return }
        domainExclusionsTip.invalidate(reason: .actionPerformed)
    }

    @available(macOS 14.0, *)
    func handleTunnelControllerAppear() {
        guard !isMenuApp else { return }

        handleTipDistanceConditionsCheckpoint()
    }

    @available(macOS 14.0, *)
    func handleTunnelControllerDisappear() {
        guard !isMenuApp else { return }

        if case .available = autoconnectTip.status {
            PixelKit.fire(VPNTipPixel.autoconnectTip(step: .ignored))
        }

        if case .available = domainExclusionsTip.status {
            PixelKit.fire(VPNTipPixel.domainExclusionsTip(step: .ignored))
        }

        if case .available = geoswitchingTip.status {
            PixelKit.fire(VPNTipPixel.geoswitchingTip(step: .ignored))
        }
    }

    @available(macOS 14.0, *)
    func handleAutoconnectionTipShown() {
        guard !isMenuApp else { return }

        PixelKit.fire(VPNTipPixel.autoconnectTip(step: .shown))
    }

    @available(macOS 14.0, *)
    func handleDomainExclusionsTipShown() {
        guard !isMenuApp else { return }

        PixelKit.fire(VPNTipPixel.domainExclusionsTip(step: .shown))
    }

    @available(macOS 14.0, *)
    func handleGeoswitchingTipShown() {
        guard !isMenuApp else { return }

        PixelKit.fire(VPNTipPixel.geoswitchingTip(step: .shown))
    }
}
