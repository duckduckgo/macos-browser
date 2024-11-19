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
import os.log
import TipKit

@MainActor
public final class VPNTipsModel: ObservableObject {

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
    private(set) var featureFlag: Bool

    private let vpnSettings: VPNSettings
    private let logger: Logger
    private var cancellables = Set<AnyCancellable>()

    public init(featureFlagPublisher: CurrentValuePublisher<Bool, Never>,
                statusObserver: ConnectionStatusObserver,
                activeSitePublisher: CurrentValuePublisher<ActiveSiteInfo?, Never>,
                forMenuApp isMenuApp: Bool,
                vpnSettings: VPNSettings,
                logger: Logger) {

        self.activeSiteInfo = activeSitePublisher.value
        self.connectionStatus = statusObserver.recentValue
        self.featureFlag = featureFlagPublisher.value
        self.logger = logger
        self.vpnSettings = vpnSettings

        if #available(macOS 14.0, *) {
            VPNDomainExclusionsTip.canShow = !isMenuApp

            handleActiveSiteInfoChanged(newValue: activeSiteInfo)
            handleConnectionStatusChanged(oldValue: connectionStatus, newValue: connectionStatus)

            subscribeToConnectionStatusChanges(statusObserver)
            subscribeToFeatureFlagChanges(featureFlagPublisher)
            subscribeToActiveSiteChanges(activeSitePublisher)
        }
    }

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

    // MARK: - Handle Refreshing

    @available(macOS 14.0, *)
    private func handleActiveSiteInfoChanged(newValue: ActiveSiteInfo?) {
        VPNDomainExclusionsTip.hasActiveSite = (activeSiteInfo != nil)
    }

    @available(macOS 14.0, *)
    private func handleConnectionStatusChanged(oldValue: ConnectionStatus, newValue: ConnectionStatus) {
        switch newValue {
        case .connected:
            if case oldValue = .connecting {
                VPNGeoswitchingTip.vpnEnabledAtLeastOnce = true
            }

            VPNAutoconnectTip.vpnEnabled = true
            VPNDomainExclusionsTip.vpnEnabled = true
        default:
            VPNAutoconnectTip.vpnEnabled = false
            VPNDomainExclusionsTip.vpnEnabled = false
        }
    }

    // MARK: - Tip Action handling

    @available(macOS 14.0, *)
    func autoconnectTipActionHandler(_ action: Tip.Action) {
        if action.id == VPNAutoconnectTip.ActionIdentifiers.enable.rawValue {
            vpnSettings.connectOnLogin = true
        }
    }

    let geoswitchingTip: VPNGeoswitchingTip = {

        let tip = VPNGeoswitchingTip()

        if #available(macOS 14.0, *) {
            Task {
                for await status in tip.statusUpdates {
                    if case .invalidated = status {
                        await VPNDomainExclusionsTip.geolocationTipDismissedEvent.donate()
                        await VPNAutoconnectTip.geolocationTipDismissedEvent.donate()
                    }
                }
            }
        }

        return tip
    }()

    /*@available(macOS 14.0, *)
    func subscribeToTipStatusChanges(_ tip: VPNGeoswitchingTip) {
        if tip.shouldDisplay {
            Task {
                for await status in tip.statusUpdates {
                    if case .invalidated = status {
                        await VPNDomainExclusionsTip.geolocationTipDismissedEvent.donate()
                        await VPNAutoconnectTip.geolocationTipDismissedEvent.donate()
                    }
                }
            }
        }
    }

    @available(macOS 14.0, *)
    func subscribeToTipStatusChanges(_ tip: VPNDomainExclusionsTip) {
        if tip.shouldDisplay {
            Task {
                for await status in tip.statusUpdates {
                    if case .invalidated = status {
                        await VPNAutoconnectTip.domainExclusionsTipDismissedEvent.donate()
                    }
                }
            }
        }
    }*/
}
