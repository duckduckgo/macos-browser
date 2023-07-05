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

    @State private var showingAlert = false

    public let dismissAction: () -> Void

    var body: some View {
        ZStack {
            closeButtonOverlay
            Spacer()
            switch model.state {
            case .noEmailProtection: unauthenticatedView
            case .authenticating: authenticatingView
            case .loadingProducts: loadingProductsView
            case .readyToPurchase: subscriptionsList
            case .errorOccurred: errorView
            }
        }
        .padding(.all, 16)
    }

    private var unauthenticatedView: some View {
        VStack {
            Text("No Email Protection")
                .font(.largeTitle)
            Text("Before purchasing a subscription please first sign in to email protection.")
        }
        .padding(.all, 32)
    }

    private var authenticatingView: some View {
        VStack {
            Text("Authenticating...")
                .font(.largeTitle)
            ActivityIndicator(isAnimating: .constant(true), style: .spinning)
        }
        .padding(.all, 32)
    }

    private var loadingProductsView: some View {
        VStack {
            Text("Loading subscriptions...")
                .font(.largeTitle)
            ActivityIndicator(isAnimating: .constant(true), style: .spinning)
        }
        .padding(.all, 32)
    }

    private var errorView: some View {
        VStack {
            Text("An error has occurred")
                .font(.largeTitle)
            Text(model.errorReason)
                .font(.headline)
            Text(model.errorDescription)
                .font(.caption)
        }
        .padding(.all, 32)
    }

    private var subscriptionsList: some View {
        VStack {
            if !model.currentEntitlements.isEmpty {
                entitlementsList
            }

            Text("Subscriptions")
                .font(.largeTitle)

            Spacer(minLength: 32)

            ScrollView {
                VStack(spacing: 32) {
                    ForEach(model.subscriptions, id: \.id) { rowModel in
                        SubscriptionRow(product: rowModel.product,
                                        isPurchased: rowModel.isPurchased,
                                        isBeingPurchased: rowModel.isBeingPurchased,
                                        buyButtonAction: { model.purchase(rowModel.product) })
                    }
                }
            }
            .disabled(model.hasOngoingPurchase)
            .opacity(model.hasOngoingPurchase ? 0.5 : 1.0)

            Spacer()

            Button {
                model.restorePurchases()
            } label: {
                Text("Restore Purchases")
            }

            Spacer()
        }
        .padding(.all, 48)
    }

    var columns: [GridItem] = [GridItem(), GridItem(.flexible()), GridItem()]

    private var entitlementsList: some View {
        VStack {
            Text("Entitlements")
                .font(.largeTitle)
            ScrollView(.horizontal) {
                HStack {
                    ForEach(model.currentEntitlements, id: \.self.id) { entitlement in
                        VStack(alignment: .leading) {
                            Text("id: \(entitlement.id)")
                            Text("name: \(entitlement.name)")
                            Text("product: \(entitlement.product)")
                        }
                        .padding()
                        .frame(height: 60)
                        .background(Color(white: 0.9))
                        .cornerRadius(15)
                    }
                    .padding()
                }
            }
        }
        .padding()
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
            HStack {
                Spacer()

                Button {
                    showingAlert = true
                } label: {
                    Image("dax-shape")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .opacity(0.3)
                }
                .buttonStyle(.borderless)
                .sheet(isPresented: $showingAlert) {
                    debugView
                }

                Spacer()
            }
        }
    }

    private var debugView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                HStack {
                    Spacer()
                    Text("Magic Menu")
                        .font(.largeTitle)
                    Text("(∩｀-´)⊃━☆ﾟ.*･｡ﾟ")
                        .font(.title)
                    Spacer()
                }
                HStack {
                    Text("Current App Store Country:")
                    Text(model.storefrontCountry)
                        .task {
                            await model.loadStorefrontCountry()
                        }
                }

                Divider()

                HStack {
                    Text("Purchased items: \(manager.purchasedProductIDs.joined(separator: ","))")
                }

                Divider()
            }
            HStack {
                Group {
                    Text("Subscription state:")

                    if let subscriptionGroupStatus = manager.subscriptionGroupStatus {
                        switch subscriptionGroupStatus {
                        case .subscribed:
                            Text("Subscribed")
                        case .expired:
                            Text("Expired")
                        case .inBillingRetryPeriod:
                            Text("In Billing Retry Period")
                        case .inGracePeriod:
                            Text("In Grace Period")
                        case .revoked:
                            Text("Revoked")
                        default:
                            Text("Unknown state")
                        }
                    } else {
                        Text("No active subscription or not signed in. \nIf expecting to have subscriptions use 'Restore purchases' button.")
                    }
                }
            }

            Group {
                Divider()
                VStack(alignment: .leading) {
                    Text("Entitlements:")
                        .font(.title2)
                    ForEach(model.currentEntitlements, id: \.self.id) { entitlement in
                        Text("id:\(entitlement.id) name:\(entitlement.name) product:\(entitlement.product)")
                    }
                }
            }

            Group {
                Divider()
                Spacer()
                Button("Refresh access token") {
                    Task {
                        switch await AccountsService.getAccessToken() {
                        case .success(let response):
                            self.model.authServiceToken = response.accessToken
                        case .failure(let error):
                            print(error)
                        }
                    }
                }

                Button("Refresh entitlements") {
                    Task {
                        switch await AccountsService.validateToken(accessToken: self.model.authServiceToken ?? "") {
                        case .success(let response):
                            self.model.externalID = response.account.externalID
                            self.model.currentEntitlements = response.account.entitlements
                        case .failure(let error):
                            print(error)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("OK") { showingAlert = false }
                Spacer()
            }
        }.padding(16)
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
