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

@available(macOS 12.0, *)
final class PurchaseViewController: NSViewController {

    private let manager = PurchaseManager.shared
    private let model = PurchaseModel()

    private var cancellables = Set<AnyCancellable>()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 600))

        let purchaseView = PurchaseView(manager: PurchaseManager.shared,
                                        model: self.model,
                                        dismissAction: { [weak self] in
            self?.dismiss()
        })

        view.addAndLayout(NSHostingView(rootView: purchaseView))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        Task {
            await manager.updatePurchasedProducts()
            await manager.updateAvailableProducts()
        }

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

    override func viewDidAppear() {
        super.viewDidAppear()
//        Task {
//            let storefront = await Storefront.current
//            print(storefront ?? "")
//        }
    }
}
