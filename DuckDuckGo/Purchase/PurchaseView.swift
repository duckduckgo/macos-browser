//
//  PurchaseView.swift
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

import SwiftUI
import StoreKit

@available(macOS 12.0, *)
struct PurchaseView: View {

    @ObservedObject var model: PurchaseModel

    public let dismissAction: () -> Void

    var body: some View {
        ZStack {
            closeButtonOverlay
            Spacer()
            if model.products.isEmpty {
                SpinnerView()
            } else {
                subscriptionsList
            }
        }
        .padding(.all, 16)
    }

    struct SpinnerView: View {
        var body: some View {
            VStack {
                Text("Fetching subscriptions...")
                    .font(.largeTitle)
                ActivityIndicator(isAnimating: .constant(true), style: .spinning)
            }
            .padding(.all, 32)
        }
    }

    private var subscriptionsList: some View {
        VStack {
            Text("Subscriptions")
                .font(.largeTitle)

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(model.products) { product in
                        SubscriptionRow(product: product,
                                        buyButtonAction: { model.buy(product) })
                    }
                }
            }

            Spacer()
        }
        .padding(.all, 32)
    }

    private var closeButtonOverlay: some View {
        VStack(alignment: .trailing) {
            HStack {
                Spacer()
                Button {
                    dismissAction()
                } label: {
                    Image(systemName: "xmark")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
            }
            Spacer()
        }
    }
}

@available(macOS 12.0, *)
struct SubscriptionRow: View {

    var product: Product
    var buyButtonAction: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(product.displayName)
                    .font(.title)
                Text(product.description)
                    .font(.body)
                Spacer()
                Text("Price: \(product.displayPrice)")
                    .font(.caption)
            }

            Spacer()

            Button {
                buyButtonAction()
            } label: {
                Text("Buy")
            }
            .buttonStyle(CapsuleButton())

        }
        .padding(33)
        .background(RoundedRectangle(cornerRadius: 10).foregroundColor(.black.opacity(0.12)))
        .disabled(!product.isSubscription)
        .opacity(product.isSubscription ? 1.0 : 0.5)
    }
}

struct CapsuleButton: ButtonStyle {

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let background = configuration.isPressed ? Color(white: 0.25) : Color(white: 0.5)

        configuration.label
            .padding(12)
            .background(background)
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}

@available(macOS 12.0, *)
extension Product {

    var isSubscription: Bool {
        type == .nonRenewable || type == .autoRenewable
    }
}

extension String: Identifiable {
    public typealias ID = Int
    public var id: Int {
        return hash
    }
}
