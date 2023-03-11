//
//  NetworkProtectionIconPublisher.swift
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
import Combine

final class NetworkProtectionIconPublisher {

    @Published
    var icon: NetworkProtectionAsset = .vpnDisabledIcon

    // MARK: - Connection Issues

    private let statusReporter: NetworkProtectionStatusReporter

    // MARK: - Subscriptions

    private var statusChangeCancellable: AnyCancellable?
    private var connectivityIssuesCancellable: AnyCancellable?

    init(statusReporter: NetworkProtectionStatusReporter = DefaultNetworkProtectionStatusReporter()) {
        self.statusReporter = statusReporter

        updateMenuIcon()
        subscribeToConnectionStatusChanges()
        subscribeToConnectionIssues()
    }

    // MARK: - Subscribing to NetP updates

    private func subscribeToConnectionStatusChanges() {
        statusChangeCancellable = statusReporter.statusChangePublisher.sink { [weak self] _ in
            self?.updateMenuIcon()
        }
    }

    private func subscribeToConnectionIssues() {
        connectivityIssuesCancellable = statusReporter.connectivityIssuesPublisher.sink { [weak self] _ in
            self?.updateMenuIcon()
        }
    }

    // MARK: - Menu Icon logic

    /// Resolves the correct icon to show, based on the current NetP status.
    ///
    private func menuIcon() -> NetworkProtectionAsset {
        guard !statusReporter.connectivityIssuesPublisher.value else {
            return .vpnIssueIcon
        }

        switch statusReporter.statusChangePublisher.value {
        case .connected:
            return .vpnIcon
        default:
            return .vpnDisabledIcon
        }
    }

    /// Updates the icon to the correct one based on NetP's status.
    ///
    private func updateMenuIcon() {
        self.icon = menuIcon()
    }
}
