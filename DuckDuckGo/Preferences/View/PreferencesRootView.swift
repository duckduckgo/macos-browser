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

#if SUBSCRIPTION
import Subscription
import SubscriptionUI
#endif

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
        static let paneContentWidth: CGFloat = 524
        static let panePaddingHorizontal: CGFloat = 40
        static let panePaddingVertical: CGFloat = 40
    }

    struct RootView: View {

        @ObservedObject var model: PreferencesSidebarModel

#if SUBSCRIPTION
        var subscriptionModel: PreferencesSubscriptionModel?
#endif

        init(model: PreferencesSidebarModel) {
            self.model = model

#if SUBSCRIPTION
            self.subscriptionModel = makeSubscriptionViewModel()
#endif
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
                                searchModel: SearchPreferences.shared)
                case .sync:
                    SyncView()
                case .appearance:
                    AppearanceView(model: .shared)
                case .dataClearing:
                    DataClearingView(model: DataClearingPreferences.shared)

#if NETWORK_PROTECTION
                case .vpn:
                    VPNView(model: VPNPreferencesModel())
#endif

#if SUBSCRIPTION
                case .subscription:
                    SubscriptionUI.PreferencesSubscriptionView(model: subscriptionModel!)
#endif
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
#if NETWORK_PROTECTION
                    let netPInvitePresenter = NetworkProtectionInvitePresenter()
                    AboutView(model: AboutModel(netPInvitePresenter: netPInvitePresenter))
#else
                    AboutView(model: AboutModel())
#endif
                }
            }
            .frame(maxWidth: Const.paneContentWidth, maxHeight: .infinity, alignment: .topLeading)
            .padding(.vertical, Const.panePaddingVertical)
            .padding(.horizontal, Const.panePaddingHorizontal)
        }

#if SUBSCRIPTION
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
                        Pixel.fire(.privacyProVPNSettings)
                        NotificationCenter.default.post(name: .ToggleNetworkProtectionInMainWindow, object: self, userInfo: nil)
                    case .openDB:
                        Pixel.fire(.privacyProPersonalInformationRemovalSettings)
                        WindowControllersManager.shared.showTab(with: .dataBrokerProtection)
                    case .openITR:
                        Pixel.fire(.privacyProIdentityRestorationSettings)
                        WindowControllersManager.shared.showTab(with: .identityTheftRestoration(.identityTheftRestoration))
                    case .iHaveASubscriptionClick:
                        Pixel.fire(.privacyProRestorePurchaseClick)
                    case .activateAddEmailClick:
                        DailyPixel.fire(pixel: .privacyProRestorePurchaseEmailStart, frequency: .dailyAndCount)
                    case .postSubscriptionAddEmailClick:
                        Pixel.fire(.privacyProSubscriptionManagementEmail, limitTo: .initial)
                    case .restorePurchaseStoreClick:
                        DailyPixel.fire(pixel: .privacyProRestorePurchaseStoreStart, frequency: .dailyAndCount)
                    case .addToAnotherDeviceClick:
                        Pixel.fire(.privacyProSettingsAddDevice)
                    case .addDeviceEnterEmail:
                        Pixel.fire(.privacyProAddDeviceEnterEmail)
                    case .activeSubscriptionSettingsClick:
                        Pixel.fire(.privacyProSubscriptionSettings)
                    case .changePlanOrBillingClick:
                        Pixel.fire(.privacyProSubscriptionManagementPlanBilling)
                    case .removeSubscriptionClick:
                        Pixel.fire(.privacyProSubscriptionManagementRemoval)
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

                        await SubscriptionAppStoreRestorer.restoreAppStoreSubscription(mainViewController: mainViewController, windowController: windowControllerManager)
                    }
                }
            },
                                                                      openURLHandler: openURL,
                                                                      uiActionHandler: handleUIEvent)

            return PreferencesSubscriptionModel(openURLHandler: openURL,
                                                userEventHandler: handleUIEvent,
                                                sheetActionHandler: sheetActionHandler,
                                                subscriptionAppGroup: Bundle.main.appGroup(bundle: .subs))
        }
#endif
    }
}
