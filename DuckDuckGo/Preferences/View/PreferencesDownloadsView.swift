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

import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct DownloadsView: View {
        @ObservedObject var model: DownloadsPreferences

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(UserText.downloads)
                    .font(Const.Fonts.preferencePaneTitle)

                PreferencePaneSection {
                    Text(UserText.downloadsLocation)
                        .font(Const.Fonts.preferencePaneSectionHeader)

                    HStack {
                        NSPathControlView(url: model.selectedDownloadLocation)
                        Button(UserText.downloadsChangeDirectory) {
                            model.presentDownloadDirectoryPanel()
                        }
                    }
                    .disabled(model.alwaysRequestDownloadLocation)

                    Toggle(UserText.downloadsAlwaysAsk, isOn: $model.alwaysRequestDownloadLocation)
                }
            }
        }
    }
}
