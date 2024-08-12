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

import Combine
import Foundation
import NetworkProtection

extension SiteTroubleshootingView {

    public final class Model: ObservableObject {

        @Published
        private(set) var isFeatureEnabled = false

        @Published
        private(set) var connectionStatus: ConnectionStatus = .disconnected

        @Published
        private var internalSiteInfo: SiteTroubleshootingInfo?

        var siteInfo: SiteTroubleshootingInfo? {
            guard case .connected = connectionStatus else {
                return nil
            }

            return internalSiteInfo
        }

        private let uiActionHandler: VPNUIActionHandling
        private var cancellables = Set<AnyCancellable>()

        public init(featureFlagPublisher: AnyPublisher<Bool, Never>,
                    connectionStatusPublisher: AnyPublisher<ConnectionStatus, Never>,
                    siteTroubleshootingInfoPublisher: AnyPublisher<SiteTroubleshootingInfo?, Never>,
                    uiActionHandler: VPNUIActionHandling) {

            self.uiActionHandler = uiActionHandler

            subscribeToConnectionStatusChanges(connectionStatusPublisher)
            subscribeToSiteTroubleshootingInfoChanges(siteTroubleshootingInfoPublisher)
            subscribeToFeatureFlagChanges(featureFlagPublisher)
        }

        private func subscribeToConnectionStatusChanges(_ publisher: AnyPublisher<ConnectionStatus, Never>) {

            publisher
                .receive(on: DispatchQueue.main)
                .assign(to: \.connectionStatus, onWeaklyHeld: self)
                .store(in: &cancellables)
        }

        private func subscribeToSiteTroubleshootingInfoChanges(_ publisher: AnyPublisher<SiteTroubleshootingInfo?, Never>) {

            publisher
                .receive(on: DispatchQueue.main)
                .assign(to: \.internalSiteInfo, onWeaklyHeld: self)
                .store(in: &cancellables)
        }

        private func subscribeToFeatureFlagChanges(_ publisher: AnyPublisher<Bool, Never>) {
            publisher
                .receive(on: DispatchQueue.main)
                .assign(to: \.isFeatureEnabled, onWeaklyHeld: self)
                .store(in: &cancellables)
        }

        func manageExclusions() {
            Task { @MainActor in
                await uiActionHandler.manageExclusions()
            }
        }

        func setExclusion(_ exclude: Bool, forDomain domain: String) {
            Task { @MainActor in
                await uiActionHandler.setExclusion(exclude, forDomain: domain)
            }
        }
    }
}
