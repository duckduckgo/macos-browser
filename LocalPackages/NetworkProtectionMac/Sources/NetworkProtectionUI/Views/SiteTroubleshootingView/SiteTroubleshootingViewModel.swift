//
//  SiteTroubleshootingViewModel.swift
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
import Foundation
import NetworkProtection
import PixelKit
import VPNPixels

extension SiteTroubleshootingView {

    public final class Model: ObservableObject {

        @Published
        private(set) var connectionStatus: ConnectionStatus = .disconnected

        @Published
        private var internalSiteInfo: ActiveSiteInfo?

        var siteInfo: ActiveSiteInfo? {
            guard case .connected = connectionStatus else {
                return nil
            }

            return internalSiteInfo
        }

        private let uiActionHandler: VPNUIActionHandling
        private let pixelKit: PixelFiring?
        private var cancellables = Set<AnyCancellable>()

        public init(connectionStatusPublisher: CurrentValuePublisher<ConnectionStatus, Never>,
                    activeSitePublisher: CurrentValuePublisher<ActiveSiteInfo?, Never>,
                    uiActionHandler: VPNUIActionHandling,
                    pixelKit: PixelFiring? = PixelKit.shared) {

            connectionStatus = connectionStatusPublisher.value
            self.uiActionHandler = uiActionHandler
            self.pixelKit = pixelKit
            internalSiteInfo = activeSitePublisher.value

            subscribeToConnectionStatusChanges(connectionStatusPublisher)
            subscribeToActiveSiteInfoChanges(activeSitePublisher)
        }

        private func subscribeToConnectionStatusChanges(_ publisher: CurrentValuePublisher<ConnectionStatus, Never>) {

            publisher
                .receive(on: DispatchQueue.main)
                .assign(to: \.connectionStatus, onWeaklyHeld: self)
                .store(in: &cancellables)
        }

        private func subscribeToActiveSiteInfoChanges(_ publisher: CurrentValuePublisher<ActiveSiteInfo?, Never>) {

            publisher
                .receive(on: DispatchQueue.main)
                .assign(to: \.internalSiteInfo, onWeaklyHeld: self)
                .store(in: &cancellables)
        }

        func setExclusion(_ exclude: Bool, forDomain domain: String) {
            Task { @MainActor in
                guard let siteInfo,
                      siteInfo.excluded != exclude else {
                    return
                }

                let engagementPixel = DomainExclusionsEngagementPixel(added: exclude)
                pixelKit?.fire(engagementPixel)

                await uiActionHandler.setExclusion(exclude, forDomain: domain)
            }
        }
    }
}
