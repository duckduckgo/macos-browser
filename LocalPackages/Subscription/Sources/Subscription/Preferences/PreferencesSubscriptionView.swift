//
//  PreferencesSubscriptionView.swift
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
    
public struct PreferencesSubscriptionView: View {
    @ObservedObject var model: PreferencesSubscriptionModel
    @State private var showingSheet = false
    @State private var showingRemoveConfirmationDialog = false

    public init(model: PreferencesSubscriptionModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // TITLE
            TextMenuTitle(text: "Privacy Pro")
                .sheet(isPresented: $showingSheet) {
                    SubscriptionAccessView(model: model.sheetModel)
                }
                .sheet(isPresented: $showingRemoveConfirmationDialog) {
                    Dialog(spacing: 20) {
                        Image("Placeholder-96x64", bundle: .module)
                        Text("Remove From This Device?")
                            .font(.title2)
                            .bold()
                            .foregroundColor(Color("TextPrimary", bundle: .module))
                        Text("You will no longer be able to access your Privacy Pro subscription on this device. This will not cancel your subscription, and it will remain active on your other devices.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .fixMultilineScrollableText()
                            .foregroundColor(Color("TextPrimary", bundle: .module))
                    } buttons: {
                        Button("Cancel") { showingRemoveConfirmationDialog = false }
                        Button(action: {
                            showingRemoveConfirmationDialog = false
                            model.removeFromThisDeviceAction()
                        }, label: {
                            Text("Remove Subscription")
                                .foregroundColor(.red)
                        })
                    }
                    .frame(width: 320)
                }

            Spacer()
                .frame(height: 20)

            VStack {
                if model.isSignedIn {
                    UniversalHeaderView {
                        Image("subscription-active-icon", bundle: .module)
                            .padding(4)
                    } content: {
                        TextMenuItemHeader(text: "Privacy Pro is active on this device")
                        TextMenuItemCaption(text: "Your monthly Privacy Pro subscription renews on April 20, 2027.")
                    } buttons: {
                        Button("Add to Another Device…") { showingSheet.toggle() }

                        Menu {
                            Button("Change Plan or Billing...", action: { model.changePlanOrBillingAction() })
                            Button("Remove From This Device...", action: {
                                showingRemoveConfirmationDialog.toggle()
                            })
                        } label: {
                            Text("Manage Subscription")
                        }
                        .fixedSize()
                    }
                } else {
                    UniversalHeaderView {
                        Image("subscription-inactive-icon", bundle: .module)
                            .padding(4)
                            .background(Color.black.opacity(0.06))
                            .cornerRadius(4)
                    } content: {
                        TextMenuItemHeader(text: "One subscription, three advanced protections")
                        TextMenuItemCaption(text: "Get enhanced protection across all your devices and reduce your online footprint for as little as $9.99/mo.")
                    } buttons: {
                        Button("Learn More") { model.learnMoreAction() }
                            .buttonStyle(DefaultActionButtonStyle(enabled: true))
                        Button("I Have a Subscription") { showingSheet.toggle() }
                    }
                }

                Divider()
                    .foregroundColor(Color.secondary)
                    .padding(.horizontal, -10)

                SectionView(iconName: "vpn-service-icon",
                            title: "VPN",
                            description: "Full-device protection with the VPN built for speed and security.",
                            buttonName: model.isSignedIn ? "Manage" : nil,
                            buttonAction: { model.openVPN() })

                Divider()
                    .foregroundColor(Color.secondary)

                SectionView(iconName: "pir-service-icon",
                            title: "Personal Information Removal",
                            description: "Find and remove your personal information from sites that store and sell it.",
                            buttonName: model.isSignedIn ? "View" : nil,
                            buttonAction: { model.openPersonalInformationRemoval() })

                Divider()
                    .foregroundColor(Color.secondary)

                SectionView(iconName: "itr-service-icon",
                            title: "Identity Theft Restoration",
                            description: "Restore stolen accounts and financial losses in the event of identity theft.",
                            buttonName: model.isSignedIn ? "View" : nil,
                            buttonAction: { model.openIdentityTheftRestoration() })
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

struct UniversalHeaderView<Icon, Content, Buttons>: View where Icon: View, Content: View, Buttons: View {

    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let content: () -> Content
    @ViewBuilder let buttons: () -> Buttons

    init(@ViewBuilder icon: @escaping () -> Icon, @ViewBuilder content: @escaping () -> Content, @ViewBuilder buttons: @escaping () -> Buttons) {
        self.icon = icon
        self.content = content
        self.buttons = buttons
    }

    public var body: some View {
        HStack(alignment: .top) {
            icon()
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
    public var iconName: String
    public var title: String
    public var description: String
    public var buttonName: String?
    public var buttonAction: (() -> Void)?

    public init(iconName: String, title: String, description: String, buttonName: String? = nil, buttonAction: (() -> Void)? = nil) {
        self.iconName = iconName
        self.title = title
        self.description = description
        self.buttonName = buttonName
        self.buttonAction = buttonAction
    }

    public var body: some View {
        VStack(alignment: .center) {
            VStack {
                HStack(alignment: .center, spacing: 8) {
                    Image(iconName, bundle: .module)
                        .padding(4)
                        .background(Color("BadgeBackground", bundle: .module))
                        .cornerRadius(4)

                    VStack (alignment: .leading) {
                        Text(title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixMultilineScrollableText()
                            .font(.body)
                            .foregroundColor(Color("TextPrimary", bundle: .module))
                        Text(description)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixMultilineScrollableText()
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(Color("TextSecondary", bundle: .module))
                    }

                    if let name = buttonName, !name.isEmpty, let action = buttonAction {
                        Button(name) { action() }
                    }
                }
            }
        }
        .padding(.vertical, 7)
    }
}

enum Const {

    static let pickerHorizontalOffset: CGFloat = {
        if #available(macOS 12.0, *) {
            return -8
        } else {
            return 0
        }
    }()

    enum Fonts {
        static let popUpButton: NSFont = .preferredFont(forTextStyle: .title1, options: [:])
        static let sideBarItem: Font = .body
        static let preferencePaneTitle: Font = .title2.weight(.semibold)
        static let preferencePaneSectionHeader: Font = .title3.weight(.semibold)
        static let preferencePaneDisclaimer: Font = .subheadline
    }
}

struct TextMenuTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Const.Fonts.preferencePaneTitle)
    }
}

struct TextMenuItemHeader: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Const.Fonts.preferencePaneSectionHeader)
    }
}

struct TextMenuItemCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixMultilineScrollableText()
            .foregroundColor(Color("GreyTextColor"))
    }
}

struct ToggleMenuItem: View {
    let title: String
    let isOn: Binding<Bool>

    var body: some View {
        Toggle(title, isOn: isOn)
            .fixMultilineScrollableText()
            .toggleStyle(.checkbox)
    }
}
