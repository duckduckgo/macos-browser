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
        enum DisplayMode: Equatable {
            case categoryView, pickerView

            var showsCheckmarkIfSelected: Bool {
                self == .categoryView
            }

            var allowsDeletingCustomBackgrounds: Bool {
                self == .pickerView
            }
        }

        let displayMode: DisplayMode
        let customBackground: CustomBackground?
        @ViewBuilder let content: () -> Content

        @State var isHovering = false
        @EnvironmentObject var model: HomePage.Models.SettingsModel

        init(
            displayMode: DisplayMode,
            customBackground: CustomBackground,
            @ViewBuilder content: @escaping () -> Content = { EmptyView() }
        ) {
            self.displayMode = displayMode
            self.customBackground = customBackground
            self.content = content
        }

        init(displayMode: DisplayMode, @ViewBuilder content: @escaping () -> Content) {
            customBackground = nil
            self.displayMode = displayMode
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
                    .frame(height: SettingsView.Const.gridItemHeight)
                    .background(selectionBackground)
                if displayMode.allowsDeletingCustomBackgrounds, case .userImage(let image) = customBackground {
                    HStack {
                        Spacer()
                        VStack {
                            CloseButton(icon: .close, size: 16) {
                                model.customImagesManager?.deleteImage(image)
                            }
                            .colorScheme(image.colorScheme)
                            .visibility(isHovering ? .visible : .gone)
                            Spacer()
                        }
                    }
                    .padding([.top, .trailing], 4)
                }
            }
            .contentShape(Rectangle())
            .onHover { isHovering in
                self.isHovering = isHovering
            }
        }

        @ViewBuilder
        private var previewContent: some View {
            switch customBackground {
            case .gradient(let gradient):
                gradient.view
            case .solidColor(let solidColor):
                if #available(macOS 12.0, *) {
                    Color(nsColor: solidColor.color)
                } else {
                    Color(hex: solidColor.color.hex())
                }
            case .userImage(let userBackgroundImage):
                Group {
                    if let image = model.customImagesManager?.thumbnailImage(for: userBackgroundImage) {
                        Image(nsImage: image).resizable().scaledToFill()
                    } else {
                        EmptyView()
                    }
                }
                .if(displayMode.allowsDeletingCustomBackgrounds) { view in
                    view.contextMenu {
                        Button(UserText.deleteBackground, action: { model.customImagesManager?.deleteImage(userBackgroundImage) })
                    }
                }
            case .none:
                content()
            }
        }

        @ViewBuilder
        private var selectionBackground: some View {
            if model.customBackground == customBackground {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.updateIndicator), lineWidth: 2)
                    if displayMode.showsCheckmarkIfSelected {
                        Image(.solidCheckmark)
                            .opacity(0.8)
                            .ifLet(customBackground?.colorScheme) { view, colorScheme in
                                view.colorScheme(colorScheme)
                            }
                    }
                }
                .padding(-2)
            }
        }
    }
}
