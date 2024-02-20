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

#if SUBSCRIPTION
import Subscription
import SubscriptionUI
#endif

enum Preferences {

    enum Const {
        static let sidebarWidth: CGFloat = 300
        static let paneContentWidth: CGFloat = 524
        static let panePaddingHorizontal: CGFloat = 48
        static let panePaddingVertical: CGFloat = 40
    }

    struct RootView: View {

        @ObservedObject var model: PreferencesSidebarModel

        var body: some View {
            HStack(spacing: 0) {
                Sidebar().environmentObject(model).frame(width: Const.sidebarWidth)

                Color(NSColor.separatorColor).frame(width: 1)

                ScrollView(.vertical) {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading) {

                            switch model.selectedPane {
                            case .defaultBrowser:
                                DefaultBrowserView(defaultBrowserModel: DefaultBrowserPreferences())
                            case .privateSearch:
                                PrivateSearchView(model: SearchPreferences.shared)
                            case .webTrackingProtection:
                                WebTrackingProtectionView(model: WebTrackingProtectionPreferences.shared)
                            case .cookiePopupProtection:
                                GeneralView(startupModel: StartupPreferences.shared)
                            case .emailProtection:
                                GeneralView(startupModel: StartupPreferences.shared)
                            case .general:
                                GeneralView(startupModel: StartupPreferences.shared)
                            case .sync:
                                SyncView()
                            case .appearance:
                                AppearanceView(model: .shared)
                            case .privacy:
                                PrivacyView(model: PrivacyPreferencesModel())

#if NETWORK_PROTECTION
                            case .vpn:
                                VPNView(model: VPNPreferencesModel())
#endif

#if SUBSCRIPTION
                            case .subscription:
                                makeSubscriptionView()
#endif
                            case .autofill:
                                AutofillView(model: AutofillPreferencesModel())
                            case .downloads:
                                DownloadsView(model: DownloadsPreferences())
                            case .duckPlayer:
                                DuckPlayerView(model: .shared)
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

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.preferencesBackground)
        }

#if SUBSCRIPTION
        private func makeSubscriptionView() -> some View {
            let openURL: (URL) -> Void = { url in
                WindowControllersManager.shared.showTab(with: .subscription(url))
            }

            let sheetActionHandler = SubscriptionAccessActionHandlers(restorePurchases: { SubscriptionPagesUseSubscriptionFeature.startAppStoreRestoreFlow() },
                                                                      openURLHandler: openURL,
                                                                      goToSyncPreferences: { self.model.selectPane(.sync) })

            let model = PreferencesSubscriptionModel(openURLHandler: openURL,
                                                     sheetActionHandler: sheetActionHandler)
            return SubscriptionUI.PreferencesSubscriptionView(model: model)
        }
#endif
    }
}

struct SyncView: View {

    var body: some View {
        if let syncService = NSApp.delegateTyped.syncService, let syncDataProviders = NSApp.delegateTyped.syncDataProviders {
            SyncUI.ManagementView(model: SyncPreferences(syncService: syncService, syncBookmarksAdapter: syncDataProviders.bookmarksAdapter))
                .onAppear {
                    requestSync()
                }
        } else {
            FailedAssertionView("Failed to initialize Sync Management View")
        }
    }

    private func requestSync() {
        Task { @MainActor in
            guard let syncService = (NSApp.delegate as? AppDelegate)?.syncService else {
                return
            }
            os_log(.debug, log: OSLog.sync, "Requesting sync if enabled")
            syncService.scheduler.notifyDataChanged()
        }
    }
}
