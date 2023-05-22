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

    @ObservedObject var manager: PurchaseManager
    @ObservedObject var model: PurchaseModel

    public let dismissAction: () -> Void

    var body: some View {
        ZStack {
            closeButtonOverlay
            Spacer()
            if model.subscriptions.isEmpty {
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

//            Text("Purchased: \(manager.purchasedProducts.map { $0.id }.joined(separator: ","))")
//
//            if let subscriptionGroupStatus = manager.subscriptionGroupStatus {
//                switch subscriptionGroupStatus {
//                case .subscribed:
//                    Text("Subscribed")
//                case .expired:
//                    Text("Expired")
//                case .inBillingRetryPeriod:
//                    Text("inBillingRetryPeriod")
//                case .inGracePeriod:
//                    Text("inGracePeriod")
//                case .revoked:
//                    Text("Revoked")
//                default:
//                    Text("Unknown state")
//                }

//                if subscriptionGroupStatus == .expired || subscriptionGroupStatus == .revoked {
//                    Text("Welcome Back! \nHead over to the shop to get started!")
//                } else if subscriptionGroupStatus == .inBillingRetryPeriod {
//                    //The best practice for subscriptions in the billing retry state is to provide a deep link
//                    //from your app to https://apps.apple.com/account/billing.
//                    Text("Please verify your billing details.")
//                }
//            } else {
//                Text("You don't own any subscriptions. \nHead over to the shop to get started!")
//            }

            ScrollView {
                VStack(spacing: 24) {
                    ForEach(model.subscriptions, id: \.id) { rowModel in
                        SubscriptionRow(product: rowModel.product,
                                        isPurchased: rowModel.isPurchased,
                                        isBeingPurchased: rowModel.isBeingPurchased,
                                        buyButtonAction: { manager.buy(rowModel.product) })
                    }
                }
            }
            .disabled(model.hasOngoingPurchase)
            .opacity(model.hasOngoingPurchase ? 0.5 : 1.0)

            Spacer()

            Button {
                Task {
                    do {
                        try await AppStore.sync()
                    } catch {
                        print(error)
                    }
                }
            } label: {
                Text("Restore Purchases")
            }
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
    @State var isPurchased: Bool = false
    @State var isBeingPurchased: Bool = false

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
                if isPurchased {
                    Text(Image(systemName: "checkmark"))
                        .bold()
                        .foregroundColor(.white)
                } else if isBeingPurchased {
                    ActivityIndicator(isAnimating: .constant(true), style: .spinning)
                } else {
                    Text("Buy")
                        .bold()
                        .foregroundColor(.white)
                }

            }
            .buttonStyle(BuyButtonStyle(isPurchased: isPurchased))

        }
        .disabled(isPurchased)
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

@available(macOS 12.0, *)
struct BuyButtonStyle: ButtonStyle {
    let isPurchased: Bool

    init(isPurchased: Bool = false) {
        self.isPurchased = isPurchased
    }

    func makeBody(configuration: Self.Configuration) -> some View {
        var bgColor: Color = isPurchased ? Color.green : Color.blue
        bgColor = configuration.isPressed ? bgColor.opacity(0.7) : bgColor.opacity(1)

        return configuration.label
            .frame(width: 50)
            .padding(10)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
    }
}
