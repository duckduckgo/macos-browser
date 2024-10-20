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
import TipKitUtils

@MainActor
public final class VPNTipsModel: ObservableObject {

    @Published
    private(set) var activeSiteInfo: ActiveSiteInfo? {
        didSet {
            guard #available(macOS 14.0, *) else {
                return
            }

            VPNDomainExclusionsTip.hasActiveSite = (activeSiteInfo != nil)
        }
    }

    @Published
    private(set) var connectionStatus: ConnectionStatus {
        didSet {
            guard #available(macOS 14.0, *) else {
                return
            }

            switch connectionStatus {
            case .connected:
                if case oldValue = .connecting {
                    Task {
                        await VPNGeoswitchingTip.vpnConnectedEvent.donate()
                    }
                }

                VPNAutoconnectTip.vpnEnabled = true
                VPNDomainExclusionsTip.vpnEnabled = true
            default:
                VPNAutoconnectTip.vpnEnabled = false
                VPNDomainExclusionsTip.vpnEnabled = false
                break
            }
        }
    }

    @Published
    private(set) var featureFlag: Bool
    let tips: TipGrouping

    private let vpnSettings: VPNSettings
    private let logger: Logger
    private var cancellables = Set<AnyCancellable>()

    static func makeTips(forMenuApp isMenuApp: Bool, logger: Logger) -> TipGrouping {

        guard #available(macOS 14.0, *) else {
            return EmptyTipGroup()
        }

        let autoconnectTip = VPNAutoconnectTip()
        let domainExclusionsTip = VPNDomainExclusionsTip()
        let geoswitchingTip = VPNGeoswitchingTip()
        let tips: [any Tip] = {
            if isMenuApp {
                return [
                    geoswitchingTip,
                    autoconnectTip
                ]
            } else {
                return [
                    geoswitchingTip,
                    domainExclusionsTip,
                    autoconnectTip
                ]
            }
        }()

        Task {
            for await statusUpdate in geoswitchingTip.statusUpdates {
                logger.debug("🪙 VPNGeoswitchingTip status updated: \(String(describing: statusUpdate), privacy: .public)")
            }
        }

        Task {
            for await statusUpdate in domainExclusionsTip.statusUpdates {
                logger.debug("🪙 VPNDomainExclusionsTip status updated: \(String(describing: statusUpdate), privacy: .public)")
            }
        }

        // This is temporarily disabled until Xcode 16 is available.
        // Ref: https://app.asana.com/0/414235014887631/1208528787265444/f
        //
        // if #available(macOS 15.0, *) {
        //     return TipGroup(.ordered) {
        //         tips
        //     }
        // } else { ... what's below
        return LegacyTipGroup(.ordered) {
            tips
        }
    }

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
        self.tips = Self.makeTips(forMenuApp: isMenuApp, logger: logger)
        self.vpnSettings = vpnSettings

        if #available(macOS 14.0, *) {
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

    // MARK: - Tip Action handling

    @available(macOS 14.0, *)
    func autoconnectTipActionHandler(_ action: Tip.Action) {
        if action.id == VPNAutoconnectTip.ActionIdentifiers.enable.rawValue {
            vpnSettings.connectOnLogin = true
        }
    }
}
