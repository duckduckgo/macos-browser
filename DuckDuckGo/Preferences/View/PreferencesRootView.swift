//
//  PreferencesRootView.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import Common
import PreferencesViews
import SwiftUI
import SwiftUIExtensions
import SyncUI
import BrowserServicesKit
import PixelKit
import Subscription
import SubscriptionUI

enum Preferences {

    enum Const {
        static var sidebarWidth: CGFloat {
            switch Locale.current.languageCode {
            case "en":
                return 310
            default:
                return 355
            }
        }
        static let paneContentWidth: CGFloat = 544
        static let panePaddingHorizontal: CGFloat = 40
        static let panePaddingVertical: CGFloat = 40
    }

    struct RootView: View {

        @ObservedObject var model: PreferencesSidebarModel

        var subscriptionModel: PreferencesSubscriptionModel?

        init(model: PreferencesSidebarModel) {
            self.model = model
            self.subscriptionModel = makeSubscriptionViewModel()
        }

        var body: some View {
            HStack(spacing: 0) {
                Sidebar().environmentObject(model).frame(width: Const.sidebarWidth)
                Color(NSColor.separatorColor).frame(width: 1)
                ScrollView(.vertical) {
                    HStack(spacing: 0) {
                        contentView
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.preferencesBackground)
        }

        @ViewBuilder
        var contentView: some View {
            VStack(alignment: .leading) {
                switch model.selectedPane {
                case .defaultBrowser:
                    DefaultBrowserView(defaultBrowserModel: DefaultBrowserPreferences.shared,
                                       status: PrivacyProtectionStatus.status(for: .defaultBrowser))
                case .privateSearch:
                    PrivateSearchView(model: SearchPreferences.shared)
                case .webTrackingProtection:
                    WebTrackingProtectionView(model: WebTrackingProtectionPreferences.shared)
                case .cookiePopupProtection:
                    CookiePopupProtectionView(model: CookiePopupProtectionPreferences.shared)
                case .emailProtection:
                    EmailProtectionView(emailManager: EmailManager())
                case .general:
                    GeneralView(startupModel: StartupPreferences.shared,
                                downloadsModel: DownloadsPreferences.shared,
                                searchModel: SearchPreferences.shared,
                                tabsModel: TabsPreferences.shared,
                                dataClearingModel: DataClearingPreferences.shared,
                                dockCustomizer: DockCustomizer())
                case .sync:
                    SyncView()
                case .appearance:
                    AppearanceView(model: .shared)
                case .dataClearing:
                    DataClearingView(model: DataClearingPreferences.shared)
                case .vpn:
                    VPNView(model: VPNPreferencesModel(), status: model.vpnProtectionStatus())
                case .subscription:
                    SubscriptionUI.PreferencesSubscriptionView(model: subscriptionModel!)
                case .autofill:
                    AutofillView(model: AutofillPreferencesModel())
                case .accessibility:
                    AccessibilityView(model: AccessibilityPreferences.shared)
                case .duckPlayer:
                    DuckPlayerView(model: .shared)
                case .otherPlatforms:
                    // Opens a new tab
                    Spacer()
                case .about:
                    AboutView(model: AboutPreferences.shared)
                }
            }
            .frame(maxWidth: Const.paneContentWidth, maxHeight: .infinity, alignment: .topLeading)
            .padding(.vertical, Const.panePaddingVertical)
            .padding(.horizontal, Const.panePaddingHorizontal)
        }

        // swiftlint:disable:next cyclomatic_complexity function_body_length
        private func makeSubscriptionViewModel() -> PreferencesSubscriptionModel {
            let openURL: (URL) -> Void = { url in
                DispatchQueue.main.async {
                    WindowControllersManager.shared.showTab(with: .subscription(url))
                }
            }

            let handleUIEvent: (PreferencesSubscriptionModel.UserEvent) -> Void = { event in
                DispatchQueue.main.async {
                    switch event {
                    case .openVPN:
                        PixelKit.fire(PrivacyProPixel.privacyProVPNSettings)
                        NotificationCenter.default.post(name: .ToggleNetworkProtectionInMainWindow, object: self, userInfo: nil)
                    case .openDB:
                        PixelKit.fire(PrivacyProPixel.privacyProPersonalInformationRemovalSettings)
                        WindowControllersManager.shared.showTab(with: .dataBrokerProtection)
                    case .openITR:
                        PixelKit.fire(PrivacyProPixel.privacyProIdentityRestorationSettings)
                        let url = Application.appDelegate.subscriptionManager.url(for: .identityTheftRestoration)
                        WindowControllersManager.shared.showTab(with: .identityTheftRestoration(url))
                    case .iHaveASubscriptionClick:
                        PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseClick)
                    case .activateAddEmailClick:
                        PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseEmailStart, frequency: .dailyAndCount)
                    case .postSubscriptionAddEmailClick:
                        PixelKit.fire(PrivacyProPixel.privacyProWelcomeAddDevice, frequency: .unique)
                    case .restorePurchaseStoreClick:
                        PixelKit.fire(PrivacyProPixel.privacyProRestorePurchaseStoreStart, frequency: .dailyAndCount)
                    case .addToAnotherDeviceClick:
                        PixelKit.fire(PrivacyProPixel.privacyProSettingsAddDevice)
                    case .addDeviceEnterEmail:
                        PixelKit.fire(PrivacyProPixel.privacyProAddDeviceEnterEmail)
                    case .activeSubscriptionSettingsClick:
                        PixelKit.fire(PrivacyProPixel.privacyProSubscriptionSettings)
                    case .changePlanOrBillingClick:
                        PixelKit.fire(PrivacyProPixel.privacyProSubscriptionManagementPlanBilling)
                    case .removeSubscriptionClick:
                        PixelKit.fire(PrivacyProPixel.privacyProSubscriptionManagementRemoval)
                    }
                }
            }

            let sheetActionHandler = SubscriptionAccessActionHandlers(restorePurchases: {
                if #available(macOS 12.0, *) {
                    Task {
                        guard let mainViewController = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController,
                              let windowControllerManager = WindowControllersManager.shared.lastKeyMainWindowController else {
                            return
                        }

                        let subscriptionAppStoreRestorer = SubscriptionAppStoreRestorer(subscriptionManager: Application.appDelegate.subscriptionManager)
                        await subscriptionAppStoreRestorer.restoreAppStoreSubscription(mainViewController: mainViewController, windowController: windowControllerManager)
                    }
                }
            },
                                                                      openURLHandler: openURL,
                                                                      uiActionHandler: handleUIEvent)

            return PreferencesSubscriptionModel(openURLHandler: openURL,
                                                userEventHandler: handleUIEvent,
                                                sheetActionHandler: sheetActionHandler,
                                                subscriptionManager: Application.appDelegate.subscriptionManager)
        }
    }
}
