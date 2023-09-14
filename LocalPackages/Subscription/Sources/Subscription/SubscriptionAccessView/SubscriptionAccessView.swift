//
//  SubscriptionAccessView.swift
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
import SwiftUIExtensions

public struct SubscriptionAccessView: View {

    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    private let dismissAction: (() -> Void)?

    let items = AccessChannel.activateItems()
    @State private var selection: UUID?
    @State var fullHeight: CGFloat = 0.0

    public init(dismiss: (() -> Void)? = nil) {
            self.dismissAction = dismiss
        print(" -- init SubscriptionAccessView")
    }

    public var body: some View {
        VStack(spacing: 8) {
            Text("Activate your subscription on this device")
                .font(.title)
            Text("Access your Privacy Pro subscription on this device via Sync, Apple ID or an email address.")
                .multilineTextAlignment(.center)
                .fixMultilineScrollableText()

            VStack(spacing: 0) {
                ForEach(items) { item in
                    SubscriptionAccessRow(name: item.name, description: item.description, isExpanded: self.selection == item.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.selection = (selection == item.id) ? nil : item.id
                        }
                        .padding(.vertical, 10)

                    if items.last != item {
                        Divider()
                    }
                }
                .padding(.horizontal, 20)
                .animation(.easeOut(duration: 0.3))
            }
            .roundedBorder()

            Spacer()
                .frame(height: 110)
                .frame(minHeight: 8)

            Divider()

            Spacer()
                .frame(height: 8)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismissAction?()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}
