//
//  BackgroundThumbnailView.swift
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

    struct BackgroundThumbnailView<Content>: View where Content: View {
        let showCheckmarkIfSelected: Bool
        let customBackground: HomePage.Models.SettingsModel.CustomBackground?
        @ViewBuilder let content: () -> Content

        @EnvironmentObject var model: HomePage.Models.SettingsModel

        init(
            showCheckmarkIfSelected: Bool = false,
            customBackground: HomePage.Models.SettingsModel.CustomBackground,
            @ViewBuilder content: @escaping () -> Content = { EmptyView() }
        ) {
            self.showCheckmarkIfSelected = showCheckmarkIfSelected
            self.customBackground = customBackground
            self.content = content
        }

        init(showCheckmarkIfSelected: Bool = false, @ViewBuilder content: @escaping () -> Content) {
            customBackground = nil
            self.showCheckmarkIfSelected = showCheckmarkIfSelected
            self.content = content
        }

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.clear)
                    .background(previewContent)
                    .cornerRadius(4)
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.homeSettingsBackgroundPreviewStroke)
                    .frame(height: 64)
                    .background(selectionBackground)
            }
            .contentShape(Rectangle())
        }

        @ViewBuilder
        private var previewContent: some View {
            switch customBackground {
            case .gradient(let gradient):
                gradient.image.resizable().scaledToFill()
            case .solidColor(let solidColor):
                solidColor.color.scaledToFill()
            case .illustration(let illustration):
                illustration.image.resizable().scaledToFill()
            case .customImage(let userBackgroundImage):
                Group {
                    if let image = model.customImagesManager.thumbnailImage(for: userBackgroundImage) {
                        Image(nsImage: image).resizable().scaledToFill()
                    } else {
                        EmptyView()
                    }
                }
                .contextMenu {
                    Button("Delete Background", action: { model.customImagesManager.deleteImage(userBackgroundImage) })
                }
            case .none:
                content()
            }
        }

        @ViewBuilder
        private var selectionBackground: some View {
            if let customBackground, model.customBackground == customBackground {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.updateIndicator), lineWidth: 2)
                    if showCheckmarkIfSelected {
                        Image(.solidCheckmark)
                            .opacity(0.8)
                            .colorScheme(customBackground.colorScheme)
                    }
                }
                .padding(-2)
            }
        }
    }
}
