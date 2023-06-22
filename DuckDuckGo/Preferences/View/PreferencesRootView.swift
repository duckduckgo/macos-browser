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

import DependencyInjection
import SwiftUI
import SwiftUIExtensions
import SyncUI

fileprivate extension Preferences.Const {
    static let sidebarWidth: CGFloat = 256
    static let paneContentWidth: CGFloat = 524
    static let panePaddingHorizontal: CGFloat = 48
    static let panePaddingVertical: CGFloat = 40
}

#if swift(>=5.9)
@Injectable
#endif
final class AbstractRootViewDependencies: Injectable {
    let dependencies: DependencyStorage

    @Injected
    var windowManager: WindowManagerProtocol

    typealias InjectedDependencies = AutofillPreferencesModel.Dependencies & PrivacyPreferencesModel.Dependencies & SyncPreferences.Dependencies

    init() {
        fatalError("\(Self.self) should not be instantiated")
    }
}

extension Preferences {

    struct RootView: View {

        @ObservedObject var model: PreferencesSidebarModel

        let dependencies: AbstractRootViewDependencies.DependencyStorage

#if NETWORK_PROTECTION
        let netPInvitePresenter: NetworkProtectionInvitePresenter
#endif

        init(model: PreferencesSidebarModel, dependencyProvider: AbstractRootViewDependencies.DependencyProvider) {
            self.dependencies = .init(dependencyProvider)
            self.model = model

#if NETWORK_PROTECTION
            self.netPInvitePresenter = NetworkProtectionInvitePresenter(windowManager: dependencies.windowManager)
#endif
        }

        var body: some View {
            HStack(spacing: 0) {
                Preferences.Sidebar().environmentObject(model).frame(width: Const.sidebarWidth)

                Color(NSColor.separatorColor).frame(width: 1)

                ScrollView(.vertical) {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading) {

                            switch model.selectedPane {
                            case .general:
                                Preferences.GeneralView(defaultBrowserModel: DefaultBrowserPreferences(), startupModel: StartupPreferences())
                            case .sync:
                                SyncView(dependencyProvider: dependencies)
                            case .appearance:
                                Preferences.AppearanceView(model: .shared)
                            case .privacy:
                                Preferences.PrivacyView(model: PrivacyPreferencesModel(dependencyProvider: dependencies))
                            case .autofill:
                                Preferences.AutofillView(model: AutofillPreferencesModel(dependencyProvider: dependencies))
                            case .downloads:
                                Preferences.DownloadsView(model: DownloadsPreferences())
                            case .duckPlayer:
                                Preferences.DuckPlayerView(model: .shared)
                            case .about:
#if NETWORK_PROTECTION
                                Preferences.AboutView(model: AboutModel(netPInvitePresenter: netPInvitePresenter, windowManager: dependencies.windowManager))
#else
                                Preferences.AboutView(model: AboutModel(windowManager: dependencies.windowManager))
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

    let dependencies: SyncPreferences.DependencyStorage

    init(dependencyProvider: SyncPreferences.DependencyProvider) {
        self.dependencies = .init(dependencyProvider)
    }

    var body: some View {
        if (NSApp.delegate as? AppDelegate)?.syncService != nil {
            SyncUI.ManagementView(model: SyncPreferences(dependencyProvider: dependencies))
        } else {
            FailedAssertionView("Failed to initialize Sync Management View")
        }
    }

}
