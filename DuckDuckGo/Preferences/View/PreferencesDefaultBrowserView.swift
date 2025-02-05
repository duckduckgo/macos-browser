//
//  PreferencesDefaultBrowserView.swift
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

import AppKit
import Combine
import PreferencesUI_macOS
import SwiftUI
import SwiftUIExtensions
import PixelKit

extension Preferences {

    struct DefaultBrowserView: View {
        @ObservedObject var defaultBrowserModel: DefaultBrowserPreferences
        @State private var isAddedToDock = false
        var dockCustomizer: DockCustomizer
        let status: PrivacyProtectionStatus

        var body: some View {
            PreferencePane(UserText.defaultBrowser, spacing: 4) {

                // SECTION 1: Status Indicator
                if let status = status.status {
                    PreferencePaneSection {
                        StatusIndicatorView(status: status, isLarge: true)
                    }
                }

                // SECTION 2: Default Browser
                PreferencePaneSection {

                    PreferencePaneSubSection {
                        HStack {
                            if defaultBrowserModel.isDefault {
                                Text(UserText.isDefaultBrowser)
                            } else {
                                HStack {
                                    Image(.warning).foregroundColor(Color(.linkBlue))
                                    Text(UserText.isNotDefaultBrowser)
                                }
                                .padding(.trailing, 8)
                                Button(action: {
                                    PixelKit.fire(GeneralPixel.defaultRequestedFromSettings)
                                    defaultBrowserModel.becomeDefault()
                                }) {
                                    Text(UserText.makeDefaultBrowser)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }

                    Spacer().frame(height: 16)

#if SPARKLE
                    PreferencePaneSection(UserText.shortcuts, spacing: 4) {
                        PreferencePaneSubSection {
                            HStack {
                                if isAddedToDock || dockCustomizer.isAddedToDock {
                                    HStack {
                                        Image(.checkCircle).foregroundColor(Color(.successGreen))
                                        Text(UserText.isAddedToDock)
                                    }
                                    .transition(.opacity)
                                    .padding(.trailing, 8)
                                } else {
                                    HStack {
                                        Image(.warning).foregroundColor(Color(.linkBlue))
                                        Text(UserText.isNotAddedToDock)
                                    }
                                    .padding(.trailing, 8)
                                    Button(action: {
                                        withAnimation {
                                            PixelKit.fire(GeneralPixel.userAddedToDockFromDefaultBrowserSection,
                                                          includeAppVersionParameter: false)
                                            dockCustomizer.addToDock()
                                            isAddedToDock = true
                                        }
                                    }) {
                                        Text(UserText.addToDock)
                                            .fixedSize(horizontal: true, vertical: false)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                            }
                        }
                    }
#endif

                }
            }
        }
    }
}
