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
                    SettingsSection(title: "Background") {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                BackgroundType(title: "Gradients", isSelected: false)
                                BackgroundType(
                                    title: "Solid Colors",
                                    isSelected: model.customBackground?.isSolidColor == true
                                )
                            }
                            HStack(spacing: 12) {
                                BackgroundType(title: "Illustrations", isSelected: false)
                                BackgroundType(title: "Upload Image", isSelected: false)
                            }
                        }
                    }
                    SettingsSection(title: "Browser Theme") {

                    }
                    SettingsSection(title: "Sections") {

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

    struct BackgroundType: View {
        let title: String
        let isSelected: Bool

        @EnvironmentObject var model: HomePage.Models.SettingsModel

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                BackgroundPreview(isSelected: isSelected) {
                    if isSelected, let preview = model.customBackground?.preview {
                        preview
                    } else {
                        EmptyView()
                    }
                }

                Text(title)
                    .font(.system(size: 11))
            }
        }
    }

}

extension HomePage.Models.SettingsModel.CustomBackground {
    var preview: some View {
        switch self {
        case .solidColor(let solidColor):
            solidColor.color
        }
    }
}

extension HomePage.Views.SettingsView {
    fileprivate typealias CloseButton = HomePage.Views.CloseButton
    fileprivate typealias SettingsSection = HomePage.Views.SettingsSection
}

extension HomePage.Views.BackgroundType {
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
