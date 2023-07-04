//
//  PurchaseViewController.swift
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
import SwiftUI
import StoreKit
import Combine
import BrowserServicesKit

@available(macOS 12.0, *)
final class PurchaseViewController: NSViewController {

    private let manager = PurchaseManager.shared
    private let model = PurchaseModel()

    private var authServiceToken: String?

    private var cancellables = Set<AnyCancellable>()

    deinit {
        print(" -- PurchaseViewController deinit --")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 650, height: 700))

        let purchaseView = PurchaseView(manager: PurchaseManager.shared,
                                        model: self.model,
                                        dismissAction: { [weak self] in
            guard let self = self else { return }
            self.presentingViewController?.dismiss(self)
        })

        view.addAndLayout(NSHostingView(rootView: purchaseView))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print(" -- PurchaseViewController viewDidLoad() --")

        update(for: initialState)

        manager.$availableProducts.combineLatest(manager.$purchasedProductIDs, manager.$purchaseQueue).receive(on: RunLoop.main).sink { [weak self] availableProducts, purchasedProductIDs, purchaseQueue in
            print(" -- got combineLatest -")
            print(" -- got combineLatest - availableProducts: \(availableProducts.map { $0.id }.joined(separator: ","))")
            print(" -- got combineLatest - purchasedProducts: \(purchasedProductIDs.joined(separator: ","))")
            print(" -- got combineLatest -     purchaseQueue: \(purchaseQueue.joined(separator: ","))")

            let sortedProducts = availableProducts.sorted(by: { $0.price > $1.price })

            self?.model.subscriptions = sortedProducts.map { SubscriptionRowModel(product: $0,
                                                                                  isPurchased: purchasedProductIDs.contains($0.id),
                                                                                  isBeingPurchased: purchaseQueue.contains($0.id)) }
        }.store(in: &cancellables)
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        print(" -- PurchaseViewController viewDidDisappear() --")
    }

    private var initialState: PurchaseModel.State {
        if hasAuthServiceToken {
            return .loadingProducts
        } else if hasEmailProtection {
            return .authenticating
        } else {
            return .noEmailProtection
        }
    }

    private var hasAuthServiceToken: Bool {
        guard let token = authServiceToken else { return false }
        return !token.isEmpty
    }

    private var hasEmailProtection: Bool {
        EmailManager().isSignedIn
    }

    private func update(for state: PurchaseModel.State) {
        print(" [[ New state -> \(state) ]]")
        model.state = state

        switch state {
        case .noEmailProtection:
            return
        case .errorOccurred(let error):
            print("Error: \(error)")
        case .authenticating:
            Task {
                switch await AccountsService.getAccessToken() {
                case .success(let response):
                    self.authServiceToken = response.accessToken
                    self.update(for: .loadingProducts)
                case .failure(let error):
                    self.update(for: .errorOccurred(error: error))
                }
            }
        case .loadingProducts:
            Task {
                switch await AccountsService.validateToken(accessToken: self.authServiceToken ?? "") {
                case .success(let response):
                    self.model.externalID = response.account.externalID
                    self.model.currentEntitlements = response.account.entitlements
                    await manager.updatePurchasedProducts()
                    await manager.updateAvailableProducts()
                    self.update(for: .readyToPurchase)
                case .failure(let error):
                    self.update(for: .errorOccurred(error: error))
                }
            }
        default:
            return
        }
    }
}
