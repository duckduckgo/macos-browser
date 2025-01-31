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

import PreferencesUI_macOS
import SwiftUI
import SwiftUIExtensions
import BrowserServicesKit

public struct PreferencesSubscriptionView: View {

    @State private var state: PreferencesSubscriptionState = .noSubscription

    @ObservedObject var model: PreferencesSubscriptionModel
    @State private var showingActivateSubscriptionSheet = false
    @State private var showingRemoveConfirmationDialog = false

    @State private var manageSubscriptionSheet: ManageSubscriptionSheet?

    private let subscriptionFeatureAvailability: SubscriptionFeatureAvailability

    public init(model: PreferencesSubscriptionModel,
                subscriptionFeatureAvailability: SubscriptionFeatureAvailability) {
        self.model = model
        self.subscriptionFeatureAvailability = subscriptionFeatureAvailability
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Title and dialogs
            TextMenuTitle(UserText.preferencesTitle)
                .sheet(isPresented: $showingActivateSubscriptionSheet) {
                    SubscriptionAccessView(model: model.sheetModel)
                }
                .sheet(isPresented: $showingRemoveConfirmationDialog) {
                    removeConfirmationDialog
                }
                .sheet(item: $manageSubscriptionSheet) { sheet in
                    switch sheet {
                    case .apple:
                        manageSubscriptionAppStoreDialog
                    case .google:
                        manageSubscriptionGooglePlayDialog
                    }
                }

            // Header
            VStack {
                switch state {
                case .noSubscription:
                    unauthenticatedHeaderView
                case .subscriptionPendingActivation:
                    pendingActivationHeaderView
                case .subscriptionActive:
                    EmptyView() // new design omits header for active subscription
                case .subscriptionExpired:
                    expiredHeaderView
                }

                if state != .subscriptionActive {
                    Divider()
                        .foregroundColor(Color.secondary)
                        .padding(.horizontal, -10)
                }

                if state == .subscriptionActive {
                    featureRowsForActiveSubscription
                } else {
                    featureRowsForNoSubscriptionView
                }
            }
            .padding(10)
            .roundedBorder()
            .padding(.top, 4)
            .padding(.bottom, 12)

            // Activate section
            if [.subscriptionActive, .subscriptionExpired].contains(state) {
                activateSection
            }

            // Settings section
            if state == .subscriptionActive {
                settingsSection
            }

            // Help section
            helpSection
        }
        .onAppear(perform: {
            model.didAppear()
        })
        .onReceive(model.statePublisher, perform: updateState(state:))
    }

    private func updateState(state: PreferencesSubscriptionState) {
        self.state = state
    }

    @ViewBuilder
    private var unauthenticatedHeaderView: some View {
        UniversalHeaderView {
            Image(.privacyPro)
                .padding(4)
                .background(Color("BadgeBackground", bundle: .module))
                .cornerRadius(4)
        } content: {
            TextMenuItemHeader(UserText.preferencesSubscriptionInactiveHeader)
            switch model.subscriptionStorefrontRegion {
            case .usa:
                TextMenuItemCaption(UserText.preferencesSubscriptionInactiveUSCaption)
            case .restOfWorld:
                TextMenuItemCaption(UserText.preferencesSubscriptionInactiveROWCaption)
            }
        } buttons: {
            Button(UserText.purchaseButton) { model.purchaseAction() }
                .buttonStyle(DefaultActionButtonStyle(enabled: true))
            Button(UserText.haveSubscriptionButton) {
                showingActivateSubscriptionSheet.toggle()
                model.userEventHandler(.iHaveASubscriptionClick)
            }
            .buttonStyle(DismissActionButtonStyle())
        }
    }

    @ViewBuilder
    private var pendingActivationHeaderView: some View {
        UniversalHeaderView {
            Image(.subscriptionPendingIcon)
                .padding(4)
        } content: {
            TextMenuItemHeader(UserText.preferencesSubscriptionPendingHeader)
            TextMenuItemCaption(UserText.preferencesSubscriptionPendingCaption)
        } buttons: {
            Button(UserText.restorePurchaseButton) { model.refreshSubscriptionPendingState() }
                .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
    }

    @ViewBuilder
    private var expiredHeaderView: some View {
        UniversalHeaderView {
            Image(.subscriptionExpiredIcon)
                .padding(4)
        } content: {
            TextMenuItemHeader(model.subscriptionDetails ?? UserText.preferencesSubscriptionInactiveHeader)
            TextMenuItemCaption(UserText.preferencesSubscriptionExpiredCaption)
        } buttons: {
            // We need to improve re-purchase flow
            Button(UserText.viewPlansExpiredButtonTitle) { model.purchaseAction() }
                .buttonStyle(DefaultActionButtonStyle(enabled: true))
            Button(UserText.removeFromThisDeviceButton, action: {
                showingRemoveConfirmationDialog.toggle()
            })
        }
    }

    @ViewBuilder
    private var featureRowsForNoSubscriptionView: some View {
        switch model.subscriptionStorefrontRegion {
        case .usa:
            SectionView(iconName: "VPN-Icon",
                        title: UserText.vpnServiceTitle,
                        description: UserText.vpnServiceDescription)

            Divider()
                .foregroundColor(Color.secondary)

            SectionView(iconName: "PIR-Icon",
                        title: UserText.personalInformationRemovalServiceTitle,
                        description: UserText.personalInformationRemovalServiceDescription)

            Divider()
                .foregroundColor(Color.secondary)

            SectionView(iconName: "ITR-Icon",
                        title: UserText.identityTheftRestorationServiceTitle,
                        description: UserText.identityTheftRestorationServiceDescription)

        case .restOfWorld:
            SectionView(iconName: "VPN-Icon",
                        title: UserText.vpnServiceTitle,
                        description: UserText.vpnServiceDescription)

            Divider()
                .foregroundColor(Color.secondary)

            SectionView(iconName: "ITR-Icon",
                        title: UserText.identityTheftRestorationServiceTitle,
                        description: UserText.identityTheftRestorationServiceDescription)
        }
    }

    @ViewBuilder
    private var featureRowsForActiveSubscription: some View {
        if model.shouldShowVPN {
            SectionView(iconName: "VPN-Icon",
                        title: UserText.vpnServiceTitle,
                        description: UserText.vpnServiceDescription,
                        buttonName: UserText.vpnServiceButtonTitle,
                        buttonAction: { model.openVPN() },
                        enabled: model.hasAccessToVPN)

            Divider()
                .foregroundColor(Color.secondary)
        }

        if model.shouldShowDBP {
            SectionView(iconName: "PIR-Icon",
                        title: UserText.personalInformationRemovalServiceTitle,
                        description: UserText.personalInformationRemovalServiceDescription,
                        buttonName: UserText.personalInformationRemovalServiceButtonTitle,
                        buttonAction: { model.openPersonalInformationRemoval() },
                        enabled: model.hasAccessToDBP)

            Divider()
                .foregroundColor(Color.secondary)
        }

        if model.shouldShowITR {
            SectionView(iconName: "ITR-Icon",
                        title: UserText.identityTheftRestorationServiceTitle,
                        description: UserText.identityTheftRestorationServiceDescription,
                        buttonName: UserText.identityTheftRestorationServiceButtonTitle,
                        buttonAction: { model.openIdentityTheftRestoration() },
                        enabled: model.hasAccessToITR)
        }
    }

    @ViewBuilder
    private var activateSection: some View {
        PreferencePaneSection {
            TextMenuItemHeader(UserText.activateSectionTitle, bottomPadding: 0)
            if model.hasEmail {
                Text(.init(UserText.activateSectionWithEmailCaption)) // required to parse markdown formatting
                    .onURLTap(onTap: { url in
                        model.openLearnMore(url)
                    })
                    .foregroundColor(Color(.textSecondary))
                    .padding(.bottom, 2)

                emailView
            } else {
                Text(.init(UserText.activateSectionNoEmailCaption)) // required to parse markdown formatting
                    .onURLTap(onTap: { url in
                        model.openLearnMore(url)
                    })
                    .foregroundColor(Color(.textSecondary))
                    .padding(.bottom, 8)

                TextButton(UserText.addEmailButton, weight: .semibold) { model.addEmailAction() }
            }
        }
    }

    @ViewBuilder
    private var settingsSection: some View {
        PreferencePaneSection {
            TextMenuItemHeader(UserText.settingsSectionTitle, bottomPadding: 0)
            TextMenuItemCaption(model.subscriptionDetails ?? "")
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 16) {
                TextButton(UserText.updatePlanOrCancelButton, weight: .semibold) {
                    model.userEventHandler(.changePlanOrBillingClick)
                    Task {
                        switch await model.changePlanOrBillingAction() {
                        case .presentSheet(let sheet):
                            manageSubscriptionSheet = sheet
                        case .navigateToManageSubscription(let navigationAction):
                            navigationAction()
                        }
                    }
                }
                TextButton(UserText.removeFromThisDeviceButton, weight: .semibold) {
                    showingRemoveConfirmationDialog.toggle()
                }
            }
        }
    }

    @ViewBuilder
    private var helpSection: some View {
        PreferencePaneSection {
            TextMenuItemHeader(UserText.preferencesSubscriptionFooterTitle, bottomPadding: 0)

            TextMenuItemCaption(UserText.preferencesSubscriptionHelpFooterCaption)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 16) {
                TextButton(UserText.viewFaqsButton, weight: .semibold) { model.openFAQ() }

                if subscriptionFeatureAvailability.usesUnifiedFeedbackForm, state == .subscriptionActive {
                    TextButton(UserText.preferencesSubscriptionFeedbackButton, weight: .semibold) { model.openUnifiedFeedbackForm() }
                }

                TextButton(UserText.preferencesPrivacyPolicyButton, weight: .semibold) { model.openPrivacyPolicy() }
            }
        }
    }

    @ViewBuilder
    private var emailView: some View {
        VStack {
            VStack(alignment: .center) {
                HStack(alignment: .center, spacing: 8) {
                    Image("email-icon", bundle: .module)
                        .padding(4)
                        .background(Color(.badgeBackground))
                        .cornerRadius(4)

                    Text(verbatim: model.email ?? "")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixMultilineScrollableText()
                        .font(.body)
                        .foregroundColor(Color(.textPrimary))

                    Button(UserText.editEmailButton) { model.editEmailAction() }
                }
            }
            .padding(.vertical, 0)
        }
        .padding(10)
        .roundedBorder()
    }

    @ViewBuilder
    private var removeConfirmationDialog: some View {
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

    @ViewBuilder
    private var manageSubscriptionAppStoreDialog: some View {
        SubscriptionDialog(imageName: "app-store",
                           title: UserText.changeSubscriptionDialogTitle,
                           description: UserText.changeSubscriptionAppleDialogDescription,
                           buttons: {
            Button(UserText.changeSubscriptionDialogDone) { manageSubscriptionSheet = nil }
                .buttonStyle(DefaultActionButtonStyle(enabled: true))
        })
        .frame(width: 360)
    }

    @ViewBuilder
    private var manageSubscriptionGooglePlayDialog: some View {
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
        Dialog {
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
            Spacer()
            buttons()
        }
    }
}
