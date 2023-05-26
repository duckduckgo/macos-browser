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
                                GeneralView(defaultBrowserModel: DefaultBrowserPreferences(), startupModel: StartupPreferences())
                            case .sync:
                                SyncView()
                            case .appearance:
                                AppearanceView(model: .shared)
                            case .privacy:
                                PrivacyView(model: PrivacyPreferencesModel())
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
