//
//  NetworkProtectionVisibilityController.swift
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

#if NETWORK_PROTECTION

import Foundation
import SwiftUI
import NetworkProtection

protocol NetworkProtectionInvitePresenting {
    func present()
}

final class NetworkProtectionInvitePresenter: NetworkProtectionInvitePresenting, NetworkProtectionInviteViewModelDelegate {

    private var presentedViewController: NSViewController?

    // MARK: NetworkProtectionInvitePresenting

    @MainActor func present() {
        let viewModel = NetworkProtectionInviteViewModel(delegate: self, redemptionCoordinator: NetworkProtectionCodeRedemptionCoordinator())

        let view = NetworkProtectionInviteDialog(model: viewModel)
        let hostingVC = NSHostingController(rootView: view)
        presentedViewController = hostingVC
        let newWindowController = hostingVC.wrappedInWindowController()

        guard let newWindow = newWindowController.window,
              let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        else {
            assertionFailure("Failed to present \(hostingVC)")
            return
        }
        parentWindowController.window?.beginSheet(newWindow)
    }

    // MARK: NetworkProtectionInviteViewModelDelegate

    func didCancelInviteFlow() {
        presentedViewController?.dismiss()
        presentedViewController = nil
    }

    func didCompleteInviteFlow() {
        Task {
            await WindowControllersManager.shared.showNetworkProtectionStatus(retry: true)
        }
        presentedViewController?.dismiss()
        presentedViewController = nil
    }
}

#endif
