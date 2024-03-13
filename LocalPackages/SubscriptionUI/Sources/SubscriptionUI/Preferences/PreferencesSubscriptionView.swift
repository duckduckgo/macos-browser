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

import PreferencesViews
import SwiftUI
import SwiftUIExtensions

public struct PreferencesSubscriptionView: View {
    @ObservedObject var model: PreferencesSubscriptionModel
    @State private var showingSheet = false
    @State private var showingRemoveConfirmationDialog = false

    @State private var manageSubscriptionSheet: ManageSubscriptionSheet?

    public init(model: PreferencesSubscriptionModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            TextMenuTitle(UserText.preferencesTitle)
                .sheet(isPresented: $showingSheet) {
                    SubscriptionAccessView(model: model.sheetModel)
                }
                .sheet(isPresented: $showingRemoveConfirmationDialog) {
                    SubscriptionDialog(imageName: "Privacy-Pro-128",
                                       title: UserText.removeSubscriptionDialogTitle,
                                       description: UserText.removeSubscriptionDialogDescription,
                                       buttons: {
                        Button(UserText.removeSubscriptionDialogCancel) { showingRemoveConfirmationDialog = false }
                        Button(action: {
                            showingRemoveConfirmationDialog = false
                            model.removeFromThisDeviceAction()
                        }, label: {
                            Text(UserText.removeSubscriptionDialogConfirm)
                                .foregroundColor(.red)
                        })
                    })
                    .frame(width: 320)
                }
                .sheet(item: $manageSubscriptionSheet) { sheet in
                    switch sheet {
                    case .apple:
                        SubscriptionDialog(imageName: "app-store",
                                           title: UserText.changeSubscriptionDialogTitle,
                                           description: UserText.changeSubscriptionAppleDialogDescription,
                                           buttons: {
                            Button(UserText.changeSubscriptionDialogDone) { manageSubscriptionSheet = nil }
                                .buttonStyle(DefaultActionButtonStyle(enabled: true))
                        })
                        .frame(width: 360)
                    case .google:
                        SubscriptionDialog(imageName: "google-play",
                                           title: UserText.changeSubscriptionDialogTitle,
                                           description: UserText.changeSubscriptionGoogleDialogDescription,
                                           buttons: {
                            Button(UserText.changeSubscriptionDialogDone) { manageSubscriptionSheet = nil }
                                .buttonStyle(DefaultActionButtonStyle(enabled: true))
                        })
                        .frame(width: 360)
                    }
                }

            Spacer()
                .frame(height: 20)

            VStack {
                if model.isUserAuthenticated {
                    UniversalHeaderView {
                        Image(.subscriptionActiveIcon)
                            .padding(4)
                    } content: {
                        TextMenuItemHeader(UserText.preferencesSubscriptionActiveHeader)
                        TextMenuItemCaption(model.subscriptionDetails ?? "")
                    } buttons: {
                        Button(UserText.addToAnotherDeviceButton) {
                            model.userEventHandler(.addToAnotherDeviceClick)
                            showingSheet.toggle()
                        }

                        Menu {
                            Button(UserText.changePlanOrBillingButton, action: {
                                model.userEventHandler(.changePlanOrBillingClick)
                                Task {
                                    switch await model.changePlanOrBillingAction() {
                                    case .presentSheet(let sheet):
                                        manageSubscriptionSheet = sheet
                                    case .navigateToManageSubscription(let navigationAction):
                                        navigationAction()
                                    }
                                }
                            })
                            Button(UserText.removeFromThisDeviceButton, action: {
                                model.userEventHandler(.removeSubscriptionClick)
                                showingRemoveConfirmationDialog.toggle()
                            })
                        } label: {
                            Text(UserText.manageSubscriptionButton)
                        }
                        .fixedSize()
                    }
                    .onAppear {
                        model.fetchAndUpdateSubscriptionDetails()
                    }

                } else {
                    UniversalHeaderView {
                        Image(.privacyPro)
                            .padding(4)
                            .background(Color("BadgeBackground", bundle: .module))
                            .cornerRadius(4)
                    } content: {
                        TextMenuItemHeader(UserText.preferencesSubscriptionInactiveHeader)
                        TextMenuItemCaption(UserText.preferencesSubscriptionInactiveCaption)
                    } buttons: {
                        Button(UserText.purchaseButton) { model.purchaseAction() }
                            .buttonStyle(DefaultActionButtonStyle(enabled: true))
                        Button(UserText.haveSubscriptionButton) {
                            showingSheet.toggle()
                            model.userEventHandler(.iHaveASubscriptionClick)
                        }
                    }
                }

                Divider()
                    .foregroundColor(Color.secondary)
                    .padding(.horizontal, -10)

                SectionView(iconName: "VPN-Icon",
                            title: UserText.vpnServiceTitle,
                            description: UserText.vpnServiceDescription,
                            buttonName: model.isUserAuthenticated ? UserText.vpnServiceButtonTitle : nil,
                            buttonAction: { model.openVPN() },
                            enabled: !model.isUserAuthenticated || model.hasAccessToVPN)

                Divider()
                    .foregroundColor(Color.secondary)

                SectionView(iconName: "PIR-Icon",
                            title: UserText.personalInformationRemovalServiceTitle,
                            description: UserText.personalInformationRemovalServiceDescription,
                            buttonName: model.isUserAuthenticated ? UserText.personalInformationRemovalServiceButtonTitle : nil,
                            buttonAction: { model.openPersonalInformationRemoval() },
                            enabled: !model.isUserAuthenticated || model.hasAccessToDBP)

                Divider()
                    .foregroundColor(Color.secondary)

                SectionView(iconName: "ITR-Icon",
                            title: UserText.identityTheftRestorationServiceTitle,
                            description: UserText.identityTheftRestorationServiceDescription,
                            buttonName: model.isUserAuthenticated ? UserText.identityTheftRestorationServiceButtonTitle : nil,
                            buttonAction: { model.openIdentityTheftRestoration() },
                            enabled: !model.isUserAuthenticated || model.hasAccessToITR)
            }
            .padding(10)
            .roundedBorder()

            Spacer()
                .frame(height: 24)

            PreferencePaneSection {
                TextMenuItemHeader(UserText.preferencesSubscriptionFooterTitle)
                HStack(alignment: .top, spacing: 6) {
                    TextMenuItemCaption(UserText.preferencesSubscriptionFooterCaption)
                    Button(UserText.viewFaqsButton) { model.openFAQ() }
                }
            }
        }
        .onAppear(perform: {
            if model.isUserAuthenticated {
                model.userEventHandler(.activeSubscriptionSettingsClick)
            }
        })
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
    public var enabled: Bool

    public init(iconName: String, title: String, description: String, buttonName: String? = nil, buttonAction: (() -> Void)? = nil, enabled: Bool = true) {
        self.iconName = iconName
        self.title = title
        self.description = description
        self.buttonName = buttonName
        self.buttonAction = buttonAction
        self.enabled = enabled
    }

    public var body: some View {
        VStack(alignment: .center) {
            VStack {
                HStack(alignment: .center, spacing: 8) {
                    Image(iconName, bundle: .module)
                        .padding(4)
                        .background(Color(.badgeBackground))
                        .cornerRadius(4)

                    VStack (alignment: .leading) {
                        Text(title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixMultilineScrollableText()
                            .font(.body)
                            .foregroundColor(Color(.textPrimary))
                        Spacer()
                            .frame(height: 4)
                        Text(description)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixMultilineScrollableText()
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(Color(.textSecondary))
                    }

                    if let name = buttonName, !name.isEmpty, let action = buttonAction {
                        Button(name) { action() }
                    }
                }
            }
        }
        .padding(.vertical, 7)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.6)
    }
}

private struct SubscriptionDialog<Buttons>: View where Buttons: View {
    public var imageName: String
    public var title: String
    public var description: String

    @ViewBuilder let buttons: () -> Buttons

    public var body: some View {
        Dialog(spacing: 20) {
            Image(imageName, bundle: .module)
            Text(title)
                .font(.title2)
                .bold()
                .foregroundColor(Color(.textPrimary))
            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .fixMultilineScrollableText()
                .foregroundColor(Color(.textPrimary))
        } buttons: {
            buttons()
        }
    }
}
