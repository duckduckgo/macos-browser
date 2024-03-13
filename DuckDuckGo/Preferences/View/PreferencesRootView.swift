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
        static let sidebarWidth: CGFloat = 310
        static let paneContentWidth: CGFloat = 524
        static let panePaddingHorizontal: CGFloat = 48
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
        private func makeSubscriptionViewModel() -> PreferencesSubscriptionModel {
            let openURL: (URL) -> Void = { url in
                DispatchQueue.main.async {
                    WindowControllersManager.shared.showTab(with: .subscription(url))
                }
            }

            let openVPN: () -> Void = {
                NotificationCenter.default.post(name: .ToggleNetworkProtectionInMainWindow, object: self, userInfo: nil)
            }

            let openDBP: () -> Void = {
                DispatchQueue.main.async {
                    WindowControllersManager.shared.showTab(with: .dataBrokerProtection)
                }
            }

            let openITR: () -> Void = {
                DispatchQueue.main.async {
                    WindowControllersManager.shared.showTab(with: .identityTheftRestoration(.identityTheftRestoration))
                }
            }

            let sheetActionHandler = SubscriptionAccessActionHandlers(restorePurchases: { SubscriptionPagesUseSubscriptionFeature.startAppStoreRestoreFlow() },
                                                                      openURLHandler: openURL)

            return PreferencesSubscriptionModel(openURLHandler: openURL,
                                                openVPNHandler: openVPN,
                                                openDBPHandler: openDBP,
                                                openITRHandler: openITR,
                                                sheetActionHandler: sheetActionHandler,
                                                subscriptionAppGroup: Bundle.main.appGroup(bundle: .subs))
        }
#endif
    }
}
