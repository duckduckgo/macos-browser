//
//  NetworkProtectionNavBarButtonModel.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

/// Model for managing the NetP button in the Nav Bar.
///
final class NetworkProtectionNavBarButtonModel: NSObject, ObservableObject {

    private let networkProtection: NetworkProtectionProvider
    private var status: NetworkProtectionConnectionStatus = .disconnected
    private let popovers: NavigationBarPopovers

    private var statusChangeCancellable: AnyCancellable?

    @Published var showButton: Bool = false

    // MARK: - Initialization

    init(popovers: NavigationBarPopovers, networkProtection: NetworkProtectionProvider = DefaultNetworkProtectionProvider()) {
        self.networkProtection = networkProtection
        self.popovers = popovers

        super.init()

        setupNetworkProtection()
    }

    // MARK: - Setup & updates

    private func setupNetworkProtection() {
        statusChangeCancellable = networkProtection.statusChangePublisher.sink { status in
            Task { @MainActor [weak self] in
                guard let self = self else {
                    return
                }

                self.status = status
                self.updateVisibility()
            }
        }
    }

    @MainActor
    private func updateVisibility() {
        guard !popovers.isNetworkProtectionPopoverShown else {
            showButton = true
            return
        }

        Task {
            switch status {
            case .connecting, .connected, .disconnecting:
                showButton = true
            default:
                showButton = false
            }
        }
    }
}

extension NetworkProtectionNavBarButtonModel: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        updateVisibility()
    }
}
