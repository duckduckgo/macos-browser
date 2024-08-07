//
//  HomePageSettingsView.swift
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

import SwiftUI
import SwiftUIExtensions

extension HomePage.Views {

    struct SettingsView: View {

        @EnvironmentObject var model: HomePage.Models.SettingsModel

        @Binding var isSettingsVisible: Bool

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 0) {
                        Text("Customize")
                            .font(.system(size: 17).bold())
                        Spacer()
                        CloseButton(icon: .closeLarge, size: 28) {
                            withAnimation {
                                isSettingsVisible = false
                            }
                        }
                    }
                    Group {
                        switch model.contentType {
                        case .root:
                            rootView
                        case .colorPicker:
                            colorPickerView
                        case .gradientPicker:
                            gradientPickerView
                        case .illustrationPicker:
                            illustrationPickerView
                        case .customImagePicker:
                            backButton(title: "Custom Image")
                        }
                    }
                    Spacer()
                }
                .frame(width: 204)
                .padding(16)
                .frame(maxHeight: .infinity)
            }
            .background(Color.homeSettingsBackground)
            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 8)
            .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 0)
        }

        func backButton(title: String) -> some View {
            Button {
                model.contentType = .root
            } label: {
                HStack(spacing: 4) {
                    Image(nsImage: .chevronMediumRight16).rotationEffect(.degrees(180))
                    Text(title).font(.system(size: 15).weight(.semibold))
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }

        @ViewBuilder
        var rootView: some View {
            SettingsSection(title: "Background") {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        BackgroundMode(title: "Gradients", isSelected: model.isGradientSelected) {
                            model.contentType = .gradientPicker
                        } backgroundPreview: {
                            model.backgroundPreview(for: .gradient)
                        }
                        BackgroundMode(title: "Solid Colors", isSelected: model.isSolidColorSelected) {
                            model.contentType = .colorPicker
                        } backgroundPreview: {
                            model.backgroundPreview(for: .solidColor)
                        }
                    }
                    HStack(spacing: 12) {
                        BackgroundMode(title: "Illustrations", isSelected: model.isIllustrationSelected) {
                            model.contentType = .illustrationPicker
                        } backgroundPreview: {
                            model.backgroundPreview(for: .illustration)
                        }
                        BackgroundMode(title: "Upload Image", isSelected: model.isCustomImageSelected) {
                            model.contentType = .customImagePicker
                        } backgroundPreview: {
                            model.backgroundPreview(for: .customImage)
                        }
                    }
                }
            }
            SettingsSection(title: "Browser Theme") {

            }
            SettingsSection(title: "Sections") {

            }
        }

        @ViewBuilder
        var colorPickerView: some View {
            VStack(spacing: 16) {
                backButton(title: "Solid Colors")
                grid(with: HomePage.Models.SettingsModel.SolidColor.allCases) { solidColor in
                    Button {
                        model.customBackground = .solidColor(solidColor)
                        model.contentType = .root
                    } label: {
                        BackgroundPreview(isSelected: false) {
                            solidColor.color.scaledToFill()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        @ViewBuilder var gradientPickerView: some View {
            VStack(spacing: 16) {
                backButton(title: "Gradients")
                grid(with: HomePage.Models.SettingsModel.Gradient.allCases) { gradient in
                    Button {
                        model.customBackground = .gradient(gradient.image)
                        model.contentType = .root
                    } label: {
                        BackgroundPreview(isSelected: false) {
                            gradient.image.resizable().scaledToFill()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        @ViewBuilder var illustrationPickerView: some View {
            VStack(spacing: 16) {
                backButton(title: "Illustrations")
                grid(with: HomePage.Models.SettingsModel.Illustration.allCases) { illustration in
                    Button {
                        model.customBackground = .illustration(illustration.image)
                        model.contentType = .root
                    } label: {
                        BackgroundPreview(isSelected: false) {
                            illustration.image.resizable().scaledToFill()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        @ViewBuilder
        func grid<T: Identifiable & Hashable>(with items: [T], @ViewBuilder itemView: @escaping (T) -> some View) -> some View {
            if #available(macOS 12.0, *) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12), count: 2),
                    spacing: 12
                ) {
                    ForEach(items, content: itemView)
                }
            } else {
                let rows = items.chunked(into: 2)
                VStack(spacing: 12) {
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row, content: itemView)
                        }
                    }
                }
            }
        }
    }

    struct SettingsSection<Content>: View where Content: View {
        let title: String
        @ViewBuilder public let content: () -> Content

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 15).weight(.semibold))
                content()
            }
        }
    }

    struct BackgroundMode<Content>: View where Content: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        @ViewBuilder public let backgroundPreview: () -> Content

        @EnvironmentObject var model: HomePage.Models.SettingsModel

        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 6) {
                    BackgroundPreview(isSelected: isSelected) {
                        backgroundPreview().scaledToFill()
                    }

                    Text(title)
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
        }
    }

    struct BackgroundPreview<Content>: View where Content: View {
        let isSelected: Bool
        @ViewBuilder public let content: () -> Content

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.clear)
                    .background(content())
                    .cornerRadius(4)
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.homeSettingsBackgroundPreviewStroke)
                    .frame(height: 64)
                    .background(selectionBackground)
            }
        }

        @ViewBuilder
        private var selectionBackground: some View {
            if isSelected {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.updateIndicator), lineWidth: 2)

                    Image(.solidCheckmark)
                        .opacity(0.64)
                }
                .padding(-2)
            }
        }
    }
}

extension HomePage.Models.SettingsModel.CustomBackground {
    @ViewBuilder
    var preview: some View {
        switch self {
        case .gradient(let image), .illustration(let image), .customImage(let image):
            image.resizable()
        case .solidColor(let solidColor):
            solidColor.color
        }
    }
}

extension HomePage.Views.SettingsView {
    fileprivate typealias CloseButton = HomePage.Views.CloseButton
    fileprivate typealias SettingsSection = HomePage.Views.SettingsSection
    fileprivate typealias BackgroundPreview = HomePage.Views.BackgroundPreview
    fileprivate typealias BackgroundMode = HomePage.Views.BackgroundMode
}

extension HomePage.Views.BackgroundMode {
    fileprivate typealias BackgroundPreview = HomePage.Views.BackgroundPreview
}

#Preview {
    @State var isSettingsVisible: Bool = true

    let model = HomePage.Models.SettingsModel()
    model.customBackground = .solidColor(.lightPink)

    return HomePage.Views.SettingsView(isSettingsVisible: $isSettingsVisible)
        .frame(width: 236)
        .environmentObject(model)
}
