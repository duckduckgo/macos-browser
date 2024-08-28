//
//  BackgroundCategoryView.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import SwiftUIExtensions

extension HomePage.Views {

    struct BackgroundCategoryView: View {
        let modeModel: HomePage.Models.SettingsModel.CustomBackgroundModeModel
        let showTitle: Bool
        let action: () -> Void

        init(modeModel: HomePage.Models.SettingsModel.CustomBackgroundModeModel, showTitle: Bool = true, action: @escaping () -> Void) {
            self.modeModel = modeModel
            self.showTitle = showTitle
            self.action = action
        }

        @EnvironmentObject var model: HomePage.Models.SettingsModel

        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 6) {
                    ZStack {
                        if modeModel.contentType == .customImagePicker && !model.hasUserImages {
                            BackgroundThumbnailView(showCheckmarkIfSelected: true) {
                                ZStack {
                                    Color.blackWhite5
                                    Image(.share)
                                }
                            }
                        } else {
                            BackgroundThumbnailView(
                                showCheckmarkIfSelected: true,
                                customBackground: modeModel.customBackgroundThumbnail ?? .solidColor(.gray)
                            )
                        }
                    }
                    if showTitle {
                        Text(modeModel.title)
                            .font(.system(size: 11))
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}
