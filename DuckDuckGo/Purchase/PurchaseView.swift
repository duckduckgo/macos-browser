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

@available(macOS 12.0, *)
struct PurchaseView: View {

    public let dismissAction: () -> Void

    var body: some View {
        ZStack {
            closeButtonOverlay
            Spacer()
//            SpinnerView()
            SubscriptionsList()
        }
        .padding(.all, 16)
    }

    struct SpinnerView: View {
        var body: some View {
            VStack {
                Text("Fetching subscriptions...")
                    .font(.largeTitle)
//                ProgressView()
                ActivityIndicator(isAnimating: .constant(true), style: .spinning)
            }
            .padding(.all, 32)
        }
    }

    struct SubscriptionsList: View {
        var body: some View {
            VStack {
                Text("Subscriptions")
                    .font(.largeTitle)

                ScrollView {
                    VStack(spacing: 16) {
                        SubscriptionRow()
                        SubscriptionRow()
                        SubscriptionRow()
                        SubscriptionRow()
                            .opacity(0.5)
                            .disabled(true)
                        SubscriptionRow()

                    }
                }

                Spacer()
            }
            .padding(.all, 32)
        }
    }

    struct SubscriptionRow: View {
        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text("Monthly Subscription")
                        .font(.title2)
                    Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
                        .font(.body)
                }

                Spacer()

                Button {
                    print("Edit button was tapped")
                } label: {
                    Text("Buy")
                }
                .buttonStyle(CapsuleButton())

            }
            .padding(33)
            .background(RoundedRectangle(cornerRadius: 10).foregroundColor(.black.opacity(0.12)))
        }
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
