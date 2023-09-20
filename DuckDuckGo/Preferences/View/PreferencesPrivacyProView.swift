//
//  PreferencesPrivacyProView.swift
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
import Subscription

extension Preferences {

    struct PrivacyProView: View {
        @ObservedObject var model: PrivacyProPreferencesModel
        @State private var showingSheet = false

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {

                // TITLE
                TextMenuTitle(text: "Privacy Pro")
                    .sheet(isPresented: $showingSheet) {
                        SubscriptionAccessView()
                    }

                Spacer()
                    .frame(height: 20)

                VStack {
                    UniversalHeaderView {
                        if model.isSignedIn {
                            TextMenuItemHeader(text: "Privacy Pro is active on this device")
                            TextMenuItemCaption(text: "Your monthly Privacy Pro subscription renews on April 20, 2027.")
                        } else {
                            TextMenuItemHeader(text: "One subscription, three advanced protections")
                            TextMenuItemCaption(text: "Get enhanced protection across all your devices and reduce your online footprint for as little as $9.99/mo.")
                        }
                    } buttons: {
                        if model.isSignedIn {
                            Button("Add to Another Device…") { showingSheet.toggle() }
                            if #available(macOS 11.0, *) {
                                Menu {
                                    Button("Change Plan or Billing...", action: { model.changePlanOrBillingAction() })
                                    Button("Remove From This Device...", action: { model.removeFromThisDeviceAction() })
                                } label: {
                                    Text("Manage Subscription")
                                }
                                .fixedSize()
                            } else {
                                // Same buttons as above
                                Button("Change Plan or Billing...", action: { model.changePlanOrBillingAction() })
                                Button("Remove From This Device...", action: { model.removeFromThisDeviceAction() })
                            }
                        } else {
                            Button("Learn More") { model.learnMoreAction() }
                                .buttonStyle(DefaultActionButtonStyle(enabled: true))
                            Button("I Have a Subscription") { showingSheet.toggle() }
                        }
                    }

                    Divider()
                        .foregroundColor(Color.secondary)
                        .padding(.horizontal, -10)

                    SectionView(title: "VPN",
                                description: "Full-device protection with the VPN built for speed and security.",
                                buttonName: model.isSignedIn ? "Manage" : "")

                    Divider()
                        .foregroundColor(Color.secondary)

                    SectionView(title: "Personal Information Removal",
                                description: "Find and remove your personal information from sites that store and sell it.",
                                buttonName: model.isSignedIn ? "View" : "")

                    Divider()
                        .foregroundColor(Color.secondary)

                    SectionView(title: "Identity Theft Restoration",
                                description: "Restore stolen accounts and financial losses in the event of identity theft.",
                                buttonName: model.isSignedIn ? "View" : "")
                }
                .padding(10)
                .roundedBorder()

                // Footer
                PreferencePaneSection {
                    TextMenuItemHeader(text: "Questions about Privacy Pro?")
                    HStack(alignment: .top, spacing: 6) {
                        TextMenuItemCaption(text: "Visit our Privacy Pro help pages for answers to frequently asked questions.")
                        Button("View FAQs") { model.openFAQ() }
                    }
                }
            }
        }
    }

    struct UniversalHeaderView<Content, Buttons>: View where Content: View, Buttons: View {

        @ViewBuilder let content: () -> Content
        @ViewBuilder let buttons: () -> Buttons

        init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder buttons: @escaping () -> Buttons) {
            self.content = content
            self.buttons = buttons
        }

        public var body: some View {
            HStack(alignment: .top) {
                Image("SubscriptionIcon")
                    .padding(4)
                    .background(Color.black.opacity(0.06))
                    .cornerRadius(4)
                VStack(alignment: .leading, spacing: 8) {

                    content()
                    HStack {
                        buttons()
                    }
                    .padding(.top, 10)
                }
                Spacer()
            }
            .padding(.vertical, 10)
        }
    }

    public struct SectionView: View {
        public var title: String
        public var description: String
        public var buttonName: String

        public init(title: String, description: String, buttonName: String) {
            self.title = title
            self.description = description
            self.buttonName = buttonName
        }

        public var body: some View {
            VStack(alignment: .center) {
                VStack {
                    HStack(alignment: .center, spacing: 8) {
                        Image("SubscriptionIcon")
                            .padding(4)
                            .background(Color.black.opacity(0.06))
                            .cornerRadius(4)

                        VStack (alignment: .leading) {
                            TextMenuItemCaption(text: title)
                            TextMenuItemCaption(text: description)
                                .font(Preferences.Const.Fonts.preferencePaneDisclaimer)
                        }

                        if !buttonName.isEmpty {
                            Button(buttonName) { }
                        }
                    }
                }
            }
            .padding(.vertical, 7)
        }
    }
}
