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

@available(macOS 12.0, *)
final class PurchaseViewController: NSViewController {

    let model = PurchaseModel()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 600))

        let purchaseView = PurchaseView(model: model, dismissAction: { [weak self] in
            self?.dismiss()
        })

        view.addAndLayout(NSHostingView(rootView: purchaseView))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        Task {
            let productIdentifiers = ["001", "monthly.subscription", "monthly1"]
            self.model.products = try await Product.products(for: productIdentifiers)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        Task {
            let productIdentifiers = ["001", "monthly.subscription", "monthly1"]
            let appProducts = try await Product.products(for: productIdentifiers)

            print(appProducts)

            let storefront = await Storefront.current
            print(storefront ?? "")
        }
    }
}
