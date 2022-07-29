//
//  PreferencesPrivacyView.swift
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

extension Preferences {

    struct PrivacyView: View {
        @ObservedObject var model: PrivacyPreferencesModel

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(UserText.privacy)
                    .font(Const.Fonts.preferencePaneTitle)

                Section {
                    Text(UserText.fireDialogFireproofSites)
                        .font(Const.Fonts.preferencePaneSectionHeader)

                    Toggle(UserText.fireproofCheckboxTitle, isOn: $model.isLoginDetectionEnabled)
                        .fixMultilineScrollableText()
                    Text(UserText.fireproofExplanation)
                        .fixMultilineScrollableText()
                    Button(UserText.manageFireproofSites) {
                        model.presentManageFireproofSitesDialog()
                    }
                }

                Section {
                    Text(UserText.autoconsentSettingsTitle)
                        .font(Const.Fonts.preferencePaneSectionHeader)

                    Toggle(UserText.autoconsentCheckboxTitle, isOn: $model.isAutoconsentEnabled)
                        .fixMultilineScrollableText()

                    Text(UserText.autoconsentExplanation)
                        .fixMultilineScrollableText()
                }

                Section {
                    Text(UserText.gpcSettingsTitle)
                        .font(Const.Fonts.preferencePaneSectionHeader)

                    Toggle(UserText.gpcCheckboxTitle, isOn: $model.isGPCEnabled)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(UserText.gpcExplanation)
                            .fixMultilineScrollableText()

                        TextButton(UserText.gpcLearnMore) {
                            model.openURL(.gpcLearnMore)
                        }
                    }
                }

                Section {
                    Text("Private Youtube Player")
                        .font(Const.Fonts.preferencePaneSectionHeader)

                    Toggle("Enable private Youtube player", isOn: $model.isPrivateYoutubePlayerEnabled)

                    Text(privateYoutubePlayerExplanation)
                        .fixMultilineScrollableText()
                }
            }
        }

        private let privateYoutubePlayerExplanation: String = {
            let bulletPoints = [
                "If YouTube shows ads in the player, they will not be personalized",
                "Views will not influence your browsing experience on YouTube",
                "Views will not be used to personalize ads that you see around the web",
                "No cookies are saved on your computer",
                "No cookies are included in the request your computer makes to Google to fetch the video"
            ]

            return bulletPoints.map({ "• " + $0 }).joined(separator: "\n")
        }()
    }
}
