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

import SwiftUI
import SwiftUIExtensions
import SyncUI

#if SUBSCRIPTION
import Subscription
import SubscriptionUI
#endif

fileprivate extension Preferences.Const {
    static let sidebarWidth: CGFloat = 256
    static let paneContentWidth: CGFloat = 524
    static let panePaddingHorizontal: CGFloat = 48
    static let panePaddingVertical: CGFloat = 40
}

extension Preferences {

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
                            case .general:
                                GeneralView(defaultBrowserModel: DefaultBrowserPreferences(), startupModel: StartupPreferences.shared)
                            case .sync:
                                SyncView()
                            case .appearance:
                                AppearanceView(model: .shared)
                            case .privacy:
                                PrivacyView(model: PrivacyPreferencesModel())
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
            .background(Color("InterfaceBackgroundColor"))
        }

#if SUBSCRIPTION

        @MainActor
        private func showProgress(with title: String) -> ProgressViewController {
            let progressVC = ProgressViewController(title: title)
            WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.presentAsSheet(progressVC)
            return progressVC
        }

        @MainActor
        private func hideProgress(_ progressVC: ProgressViewController) {
            WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.dismiss(progressVC)
        }

        private func makeSubscriptionView() -> some View {
            let actionHandler = PreferencesSubscriptionActionHandlers(openURL: { url in
                WindowControllersManager.shared.show(url: url, newTab: true)
            }, manageSubscriptionInAppStore: {
                NSWorkspace.shared.open(.manageSubscriptionsInAppStoreAppURL)
            }, openVPN: {
                print("openVPN")
            }, openPersonalInformationRemoval: {
                print("openPersonalInformationRemoval")
            }, openIdentityTheftRestoration: {
                print("openIdentityTheftRestoration")
            })

            let sheetActionHandler = SubscriptionAccessActionHandlers(restorePurchases: {
                if #available(macOS 12.0, *) {
                    Task {
                        let progressViewController = self.showProgress(with: "Restoring subscription...")

                        defer { self.hideProgress(progressViewController) }

                        guard case .success = await PurchaseManager.shared.syncAppleIDAccount() else { return }

                        switch await AppStoreRestoreFlow.restoreAccountFromPastPurchase() {
                        case .success:
                            break
                        case .failure(let error):
                            switch error {
                            case .missingAccountOrTransactions:
                                self.showSubscriptionNotFoundAlert()
                            case .subscriptionExpired:
                                self.showSubscriptionInactiveAlert()
                            default:
                                self.showSomethingWentWrongAlert()
                            }
                        }
                    }
                }
            }, openURLHandler: { url in
                WindowControllersManager.shared.show(url: url, newTab: true)
            }, goToSyncPreferences: {
                self.model.selectPane(.sync)
            })

            let model = PreferencesSubscriptionModel(actionHandler: actionHandler, sheetActionHandler: sheetActionHandler)
            return SubscriptionUI.PreferencesSubscriptionView(model: model)
        }

        @MainActor
        private func showSomethingWentWrongAlert() {
            guard let window = WindowControllersManager.shared.lastKeyMainWindowController?.window else { return }

            let alert = NSAlert.somethingWentWrongAlert()
            alert.beginSheetModal(for: window)
        }
        
        @MainActor
        private func showSubscriptionNotFoundAlert() {
            guard let window = WindowControllersManager.shared.lastKeyMainWindowController?.window else { return }

            let alert = NSAlert.subscriptionNotFoundAlert()
            alert.beginSheetModal(for: window, completionHandler: { response in
                if case .alertFirstButtonReturn = response {
                    WindowControllersManager.shared.show(url: .purchaseSubscription, newTab: true)
                }
            })
        }

        @MainActor
        private func showSubscriptionInactiveAlert() {
            guard let window = WindowControllersManager.shared.lastKeyMainWindowController?.window else { return }

            let alert = NSAlert.subscriptionInactiveAlert()
            alert.beginSheetModal(for: window, completionHandler: { response in
                if case .alertFirstButtonReturn = response {
                    WindowControllersManager.shared.show(url: .purchaseSubscription, newTab: true)
                }
            })
        }
#endif
    }
}

struct SyncView: View {

    var body: some View {
        if let syncService = (NSApp.delegate as? AppDelegate)?.syncService {
            SyncUI.ManagementView(model: SyncPreferences(syncService: syncService))
        } else {
            FailedAssertionView("Failed to initialize Sync Management View")
        }
    }

}
