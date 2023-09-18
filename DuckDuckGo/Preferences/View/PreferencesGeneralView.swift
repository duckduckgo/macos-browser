//
//  PreferencesGeneralView.swift
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
import AppKit
import Combine
import SwiftUIExtensions

extension Preferences {

    struct GeneralView: View {
        @ObservedObject var defaultBrowserModel: DefaultBrowserPreferences
        @ObservedObject var startupModel: StartupPreferences

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {

                // TITLE
                TextMenuTitle(text: UserText.general)

                // SECTION 1: Default Browser
                PreferencePaneSection {
                    TextMenuItemHeader(text: UserText.defaultBrowser)

                    HStack {
                        if defaultBrowserModel.isDefault {
                            Image("SolidCheckmark")
                            Text(UserText.isDefaultBrowser)
                        } else {
                            Image("Warning").foregroundColor(Color("LinkBlueColor"))
                            Text(UserText.isNotDefaultBrowser)
                            Button(UserText.makeDefaultBrowser) {
                                defaultBrowserModel.becomeDefault()
                            }
                        }
                    }
                }

                // SECTION 2: On Startup
                PreferencePaneSection {
                    TextMenuItemHeader(text: UserText.onStartup)
                    Picker(selection: $startupModel.restorePreviousSession, content: {
                        Text(UserText.showHomePage).tag(false)
                        Text(UserText.reopenAllWindowsFromLastSession).tag(true)
                    }, label: {})
                    .pickerStyle(.radioGroup)
                    .offset(x: Const.pickerHorizontalOffset)
                }

                // SECTION 3: Home Page
                PreferencePaneSection {
                    TextMenuItemHeader(text: UserText.homePage)
                    Picker(selection: $startupModel.launchToCustomHomePage, label: EmptyView()) {
                        Text(UserText.newTab).tag(false)
                        VStack(alignment: .leading) {
                            HStack(spacing: 15) {
                                Text(UserText.specificPage)
                                Button(UserText.setPage) {}
                                    .disabled(!startupModel.launchToCustomHomePage)
                            }
                            TextMenuItemCaption(text: startupModel.customHomePageFormatted)
                                .padding(.top, 0)
                                .visibility(!startupModel.launchToCustomHomePage ? .gone : .visible)
                        }.tag(true)
                    }
                    .pickerStyle(.radioGroup)
                    .offset(x: Const.pickerHorizontalOffset)
                    .padding(.bottom, 0)
                }

            }
        }
    }
}
