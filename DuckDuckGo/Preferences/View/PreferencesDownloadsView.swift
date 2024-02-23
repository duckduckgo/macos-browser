//
//  PreferencesDownloadsView.swift
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

import PreferencesViews
import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct DownloadsView: View {
        @ObservedObject var model: DownloadsPreferences

        @State var selectedNumber = 0
        var body: some View {
            PreferencePane(UserText.downloads) {

                PreferencePaneSubSection {
                    ToggleMenuItem(UserText.downloadsOpenPopupOnCompletion,
                                   isOn: $model.shouldOpenPopupOnCompletion)
                }

                // MARK: Location
                PreferencePaneSection(UserText.downloadsLocation) {

                    HStack {
                        NSPathControlView(url: model.selectedDownloadLocation)
#if !APPSTORE
                        Button(UserText.downloadsChangeDirectory) {
                            model.presentDownloadDirectoryPanel()
                        }
#endif
                    }
                    .disabled(model.alwaysRequestDownloadLocation)
                    ToggleMenuItem(UserText.downloadsAlwaysAsk,
                                   isOn: $model.alwaysRequestDownloadLocation)
                }
            }
        }
    }
}

#Preview {
    VStack {
        HStack {
            Preferences.DownloadsView(model: DownloadsPreferences())
                .padding()
            Spacer()
        }.frame(width: 500)

    }.background(Color.preferencesBackground)
}
