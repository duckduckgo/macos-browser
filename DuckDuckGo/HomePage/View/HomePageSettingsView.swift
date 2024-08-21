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

        let includingContinueSetUpCards: Bool
        @EnvironmentObject var model: HomePage.Models.SettingsModel
        @EnvironmentObject var appearancePreferences: AppearancePreferences
        @EnvironmentObject var continueSetUpModel: HomePage.Models.ContinueSetUpModel
        @EnvironmentObject var favoritesModel: HomePage.Models.FavoritesModel

        @Binding var isSettingsVisible: Bool

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 0) {
                        Text("Customize")
                            .font(.system(size: 17).bold())
                        Spacer()
                        CloseButton(icon: .closeLarge, size: 28) {
                            if #available(macOS 14.0, *) {
                                withAnimation {
                                    isSettingsVisible = false
                                } completion: {
                                    model.contentType = .root
                                }
                            } else {
                                withAnimation {
                                    isSettingsVisible = false
                                    model.contentType = .root
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 36) {
                        switch model.contentType {
                        case .root, .addImage:
                            rootView
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        case .colorPicker:
                            colorPickerView
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        case .gradientPicker:
                            gradientPickerView
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        case .illustrationPicker:
                            illustrationPickerView
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        case .customImagePicker:
                            userBackgroundImagePickerView
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.none, value: model.customBackground)

                    Spacer()
                }
                .frame(width: 204)
                .padding(16)
                .frame(maxHeight: .infinity)
            }
            .background(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.homeSettingsBackground)
                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 8)
                        .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 0)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            )
        }

        var footer: some View {
            VStack(spacing: 18) {
                Divider()

                Button {
                    model.openSettings()
                } label: {
                    HStack {
                        Text("All Settings")
                        Spacer()
                        Image(.externalAppScheme)
                    }
                    .foregroundColor(Color.linkBlue)
                    .cursor(.pointingHand)
                }
                .buttonStyle(.plain)
            }
        }

        func backButton(title: String) -> some View {
            Button {
                withAnimation {
                    model.contentType = .root
                }
            } label: {
                HStack(spacing: 4) {
                    Image(nsImage: .chevronMediumRight16).rotationEffect(.degrees(180))
                    Text(title).font(.system(size: 15).weight(.semibold))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }

        @ViewBuilder
        var rootView: some View {
            SettingsSection(title: "Background") {
                grid(with: model.customBackgroundModes) { mode in
                    BackgroundMode(modeModel: mode) {
                        withAnimation {
                            model.contentType = mode.contentType
                        }
                    }
                }
                TextButton("Reset Background") {
                    withAnimation {
                        model.customBackground = nil
                    }
                }
            }
            .animation(.none, value: model.customBackground)
            SettingsSection(title: "Browser Theme") {
                ThemePicker()
            }
            SettingsSection(title: "Sections") {
                HomeContentSectionsView(includeContinueSetUpCards: includingContinueSetUpCards)
            }
            footer

            SettingsSection(title: "Sections Background") {
                HStack {
                    Text("Color").font(.system(size: 13.0, weight: .semibold))
                    if #available(macOS 12.0, *) {
                        Spacer()
                        ZStack {
                            Rectangle()
                                .foregroundColor(Color(nsColor: model.backgroundColor))
                            Rectangle()
                                .stroke(Color.black.opacity(0.12))
                        }
                        .frame(width: 40, height: 20)
                    }
                }
                HStack {
                    Slider(value: $model.backgroundColorRed, in: 0...1.0) {
                        Color.red.frame(width: 24, height: 24)
                    }
                    Text(String(format: "%.2f", arguments: [model.backgroundColorRed]))
                        .frame(width: 30)
                }
                HStack {
                    Slider(value: $model.backgroundColorGreen, in: 0...1.0) {
                        Color.green.frame(width: 24, height: 24)
                    }
                    Text(String(format: "%.2f", arguments: [model.backgroundColorGreen]))
                        .frame(width: 30)
                }
                HStack {
                    Slider(value: $model.backgroundColorBlue, in: 0...1.0) {
                        Color.blue.frame(width: 24, height: 24)
                    }
                    Text(String(format: "%.2f", arguments: [model.backgroundColorBlue]))
                        .frame(width: 30)
                }
                HStack {
                    Slider(value: $model.backgroundColorAlpha, in: 0...1.0) {
                        ZStack {
                            Rectangle()
                                .fill(Color.colorSchemePickerWhite)
                                .clipShape(Rectangle().offset(x: -12))
                            Rectangle()
                                .fill(Color.colorSchemePickerBlack)
                                .clipShape(Rectangle().offset(x: 12))
                            Rectangle()
                                .stroke(Color.black.opacity(0.12))
                        }
                        .frame(width: 24, height: 24)
                        .clipped()
                    }
                    Text(String(format: "%.2f", arguments: [model.backgroundColorAlpha]))
                        .frame(width: 30)
                }

                Text("Vibrancy Material").font(.system(size: 13.0, weight: .semibold))
                Picker(selection: $model.vibrancyMaterial, content: {
                    Text("titlebar").tag(NSVisualEffectView.Material.titlebar)
                    Text("selection").tag(NSVisualEffectView.Material.selection)
                    Text("menu").tag(NSVisualEffectView.Material.menu)
                    Text("popover").tag(NSVisualEffectView.Material.popover)
                    Text("sidebar").tag(NSVisualEffectView.Material.sidebar)
                    Text("headerView").tag(NSVisualEffectView.Material.headerView)
                    Text("sheet").tag(NSVisualEffectView.Material.sheet)
                    Text("windowBackground").tag(NSVisualEffectView.Material.windowBackground)
                    Text("hudWindow").tag(NSVisualEffectView.Material.hudWindow)
                    Text("fullScreenUI").tag(NSVisualEffectView.Material.fullScreenUI)
                    Text("toolTip").tag(NSVisualEffectView.Material.toolTip)
                    Text("contentBackground").tag(NSVisualEffectView.Material.contentBackground)
                    Text("underWindowBackground").tag(NSVisualEffectView.Material.underWindowBackground)
                    Text("underPageBackground").tag(NSVisualEffectView.Material.underPageBackground)
                }, label: {})
                .pickerStyle(.radioGroup)

                Text("Alpha").font(.system(size: 13.0, weight: .semibold))
                HStack {
                    Slider(value: $model.vibrancyAlpha, in: 0...1.0) {
                    } minimumValueLabel: {
                        Text("0")
                    } maximumValueLabel: {
                        Text("1")
                    }
                    Text(String(format: "%.2f", arguments: [model.vibrancyAlpha]))
                        .frame(width: 30)
                }
            }
        }

        @ViewBuilder
        var colorPickerView: some View {
            VStack(spacing: 16) {
                backButton(title: "Solid Colors")
                grid(with: HomePage.Models.SettingsModel.SolidColor.allCases) { solidColor in
                    Button {
                        withAnimation {
                            if model.customBackground != .solidColor(solidColor) {
                                model.customBackground = .solidColor(solidColor)
                            }
                        }
                    } label: {
                        BackgroundPreview(customBackground: .solidColor(solidColor))
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        @ViewBuilder
        var gradientPickerView: some View {
            VStack(spacing: 16) {
                backButton(title: "Gradients")
                grid(with: HomePage.Models.SettingsModel.Gradient.allCases) { gradient in
                    Button {
                        withAnimation {
                            if model.customBackground != .gradient(gradient) {
                                model.customBackground = .gradient(gradient)
                            }
                        }
                    } label: {
                        BackgroundPreview(customBackground: .gradient(gradient))
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        @ViewBuilder
        var illustrationPickerView: some View {
            VStack(spacing: 16) {
                backButton(title: "Illustrations")
                grid(with: HomePage.Models.SettingsModel.Illustration.allCases) { illustration in
                    Button {
                        withAnimation {
                            if model.customBackground != .illustration(illustration) {
                                model.customBackground = .illustration(illustration)
                            }
                        }
                    } label: {
                        BackgroundPreview(customBackground: .illustration(illustration))
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        @ViewBuilder
        var userBackgroundImagePickerView: some View {
            VStack(spacing: 16) {
                backButton(title: "My Images")
                grid(with: model.availableUserBackgroundImages) { userBackgroundImage in
                    Button {
                        withAnimation {
                            if model.customBackground != .customImage(userBackgroundImage) {
                                model.customBackground = .customImage(userBackgroundImage)
                            }
                        }
                    } label: {
                        BackgroundPreview(customBackground: .customImage(userBackgroundImage))
                    }
                    .buttonStyle(.plain)
                }
                addBackgroundButton
                Text("Images are stored on your device so DuckDuckGo can't see or access them.")
                    .foregroundColor(.blackWhite60)
                    .multilineTextAlignment(.leading)
            }
        }

        @ViewBuilder
        var addBackgroundButton: some View {
            let button = Button {
                model.addNewImage()
            } label: {
                Text("Add Background")
                    .frame(maxWidth: .infinity)
            }
                .controlSize(.large)

            if #available(macOS 12.0, *) {
                button.buttonStyle(.borderedProminent)
            } else {
                button.buttonStyle(DefaultActionButtonStyle(enabled: true))
            }
        }

        @ViewBuilder
        func grid<T: Identifiable & Hashable>(with items: [T], @ViewBuilder itemView: @escaping (T) -> some View) -> some View {
            if #available(macOS 12.0, *), items.count > 1 {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12), count: 2),
                    spacing: 12
                ) {
                    ForEach(items, content: itemView)
                }
            } else {
                let rows = items.chunked(into: 2)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row) { row in
                                itemView(row).frame(width: 96)
                            }
                            if row.count == 1 {
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    struct ThemePicker: View {
        @EnvironmentObject var appearancePreferences: AppearancePreferences

        var body: some View {
            HStack(spacing: 24) {
                ForEach(ThemeName.allCases, id: \.self) { theme in
                    themeButton(for: theme)
                }
            }
        }

        func themeButton(for themeName: ThemeName) -> some View {
            Button {
                appearancePreferences.currentThemeName = themeName
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        themeName.pickerView
                        Circle()
                            .stroke(Color.black.opacity(0.12))
                    }
                    .frame(width: 42, height: 42)
                    .padding(2)
                    .background(selectionBackground(for: themeName))

                    Text(themeName.displayName)
                }
            }
            .buttonStyle(.plain)
        }

        func selectionBackground(for themeName: ThemeName) -> some View {
            Group {
                if appearancePreferences.currentThemeName == themeName {
                    Circle()
                        .stroke(Color(.linkBlue), lineWidth: 2)
                } else {
                    EmptyView()
                }
            }
        }
    }

    struct SettingsSection<Content>: View where Content: View {
        let title: String
        @ViewBuilder let content: () -> Content

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 15).weight(.semibold))
                content()
            }
        }
    }

    struct BackgroundMode: View {
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
                        if modeModel.contentType == .addImage {
                            BackgroundPreview(showSelectionCheckmark: true) {
                                ZStack {
                                    Color.blackWhite5
                                    Image(.share)
                                }
                            }
                        } else {
                            BackgroundPreview(
                                showSelectionCheckmark: true,
                                customBackground: modeModel.customBackgroundPreview ?? .solidColor(.gray)
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

    struct BackgroundPreview<Content>: View where Content: View {
        let showSelectionCheckmark: Bool
        let customBackground: HomePage.Models.SettingsModel.CustomBackground?
        @ViewBuilder let content: () -> Content

        @EnvironmentObject var model: HomePage.Models.SettingsModel

        init(
            showSelectionCheckmark: Bool = false,
            customBackground: HomePage.Models.SettingsModel.CustomBackground,
            @ViewBuilder content: @escaping () -> Content = { EmptyView() }
        ) {
            self.showSelectionCheckmark = showSelectionCheckmark
            self.customBackground = customBackground
            self.content = content
        }

        init(showSelectionCheckmark: Bool = false, @ViewBuilder content: @escaping () -> Content) {
            customBackground = nil
            self.showSelectionCheckmark = showSelectionCheckmark
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
                    if showSelectionCheckmark {
                        Image(.solidCheckmark)
                            .opacity(0.8)
                            .colorScheme(customBackground.colorScheme)
                    }
                }
                .padding(-2)
            }
        }
    }

    struct HomeContentSectionsView: View {
        let includeContinueSetUpCards: Bool
        @EnvironmentObject var model: AppearancePreferences
        @EnvironmentObject var continueSetUpModel: HomePage.Models.ContinueSetUpModel
        @EnvironmentObject var favoritesModel: HomePage.Models.FavoritesModel
        let iconSize: CGFloat = 16

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                if includeContinueSetUpCards {
                    Toggle(isOn: $model.isContinueSetUpVisible) {
                        HStack {
                            Image(.rocketGrayscale)
                                .frame(width: iconSize, height: iconSize)
                            Text(UserText.newTabSetUpSectionTitle)
                            Spacer()
                        }
                    }
                    .toggleStyle(.switch)
                    .visibility(continueSetUpModel.hasContent ? .visible : .gone)
                }

                Toggle(isOn: $model.isFavoriteVisible) {
                    HStack {
                        Image(.favorite)
                            .frame(width: iconSize, height: iconSize)
                        Text(UserText.newTabFavoriteSectionTitle)
                        Spacer()
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $model.isRecentActivityVisible) {
                    HStack {
                        Image(.shield)
                            .frame(width: iconSize, height: iconSize)
                        Text(UserText.newTabRecentActivitySectionTitle)
                        Spacer()
                    }
                }
                .toggleStyle(.switch)
            }
        }
    }
}

fileprivate extension ThemeName {
    @ViewBuilder
    var pickerView: some View {
        switch self {
        case .light:
            Circle().fill(Color.colorSchemePickerWhite)
        case .dark:
            Circle().fill(Color.colorSchemePickerBlack)
        case .systemDefault:
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(Color.colorSchemePickerWhite)
                        .clipShape(Rectangle().offset(x: -geometry.size.width/2))
                    Circle()
                        .fill(Color.colorSchemePickerBlack)
                        .clipShape(Rectangle().offset(x: geometry.size.width/2))
                }
            }
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

    let model = HomePage.Models.SettingsModel(openSettings: {})
    model.customBackground = .solidColor(.lightPink)

    return HomePage.Views.SettingsView(includingContinueSetUpCards: true, isSettingsVisible: $isSettingsVisible)
        .frame(width: 236)
        .environmentObject(model)
}
