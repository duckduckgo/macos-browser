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

import AppKit
import Foundation
import Combine
import NetworkProtection

public protocol IconProvider {
    var onIcon: NetworkProtectionAsset { get }
    var offIcon: NetworkProtectionAsset { get }
    var issueIcon: NetworkProtectionAsset { get }
}

public final class NetworkProtectionIconPublisher {

    // MARK: - Icon

    /// The object that provides the icons to use.
    ///
    private let iconProvider: IconProvider

    @Published
    public var icon: NetworkProtectionAsset

    // MARK: - Connection Issues

    private let statusReporter: NetworkProtectionStatusReporter

    // MARK: - Subscriptions

    private var statusChangeCancellable: AnyCancellable?
    private var connectivityIssuesCancellable: AnyCancellable?

    public init(statusReporter: NetworkProtectionStatusReporter, iconProvider: IconProvider) {
        self.statusReporter = statusReporter
        self.iconProvider = iconProvider
        icon = iconProvider.offIcon

        updateMenuIcon()
        subscribeToConnectionStatusChanges()
        subscribeToConnectionIssues()
    }

    // MARK: - Subscribing to NetP updates

    private func subscribeToConnectionStatusChanges() {
        statusChangeCancellable = statusReporter.statusObserver.publisher.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.updateMenuIcon()
        }
    }

    private func subscribeToConnectionIssues() {
        connectivityIssuesCancellable = statusReporter.connectivityIssuesObserver.publisher.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.updateMenuIcon()
        }
    }

    // MARK: - Menu Icon logic

    /// Resolves the correct icon to show, based on the current NetP status.
    ///
    private func menuIcon() -> NetworkProtectionAsset {
        guard !statusReporter.connectivityIssuesObserver.recentValue else {
            return iconProvider.issueIcon
        }

        switch statusReporter.statusObserver.recentValue {
        case .connected:
            return iconProvider.onIcon
        default:
            return iconProvider.offIcon
        }
    }

    /// Updates the icon to the correct one based on NetP's status.
    ///
    private func updateMenuIcon() {
        self.icon = menuIcon()
    }
}
