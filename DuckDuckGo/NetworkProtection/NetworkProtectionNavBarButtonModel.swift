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
    private let networkProtectionStatusReporter: NetworkProtectionStatusReporter
    private var status: NetworkProtectionConnectionStatus = .disconnected
    private let popovers: NavigationBarPopovers

    // MARK: - Subscriptions
    
    private var statusChangeCancellable: AnyCancellable?
    private var interruptionCancellable: AnyCancellable?
    
    // MARK: - NetP Icon publisher
    
    private let iconPublisher: NetworkProtectionIconPublisher
    private var iconPublisherCancellable: AnyCancellable?

    // MARK: - Button appearance

    @Published
    private(set) var showButton = false
    
    @Published
    private(set) var buttonImage: NSImage?
    
    // MARK: - NetP State

    private var isHavingConnectivityIssues = false

    // MARK: - Initialization

    init(popovers: NavigationBarPopovers,
         networkProtection: NetworkProtectionProvider = DefaultNetworkProtectionProvider(),
         networkProtectionStatusReporter: NetworkProtectionStatusReporter = DefaultNetworkProtectionStatusReporter()) {
        self.networkProtection = networkProtection
        self.networkProtectionStatusReporter = networkProtectionStatusReporter
        self.iconPublisher = NetworkProtectionIconPublisher(statusReporter: networkProtectionStatusReporter)
        self.popovers = popovers
        
        isHavingConnectivityIssues = networkProtectionStatusReporter.connectivityIssuesPublisher.value
        buttonImage = .init(iconPublisher.icon)

        super.init()

        setupSubscriptions()
    }

    // MARK: - Subscriptions
    
    private func setupSubscriptions() {
        setupIconSubscription()
        setupStatusSubscription()
        setupInterruptionSubscription()
    }
    
    private func setupIconSubscription() {
        iconPublisherCancellable = iconPublisher.$icon.sink { [weak self] icon in
            self?.buttonImage = .init(icon)
        }
    }

    private func setupStatusSubscription() {
        statusChangeCancellable = networkProtectionStatusReporter.statusChangePublisher.sink { [weak self] status in
            guard let self = self else {
                return
            }
            
            Task { @MainActor in
                self.status = status
                self.updateVisibility()
            }
        }
    }
    
    private func setupInterruptionSubscription() {
        interruptionCancellable = networkProtectionStatusReporter.connectivityIssuesPublisher.sink { [weak self] isHavingConnectivityIssues in
            guard let self = self else {
                return
            }
            
            Task { @MainActor in
                self.isHavingConnectivityIssues = isHavingConnectivityIssues
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
            guard !isHavingConnectivityIssues else {
                showButton = true
                return
            }
            
            switch status {
            case .connecting, .connected, .reasserting, .disconnecting:
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
