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

                    header

                    VStack(alignment: .leading, spacing: 36) {
                        switch model.contentType {
                        case .root:
                            rootView
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        case .colorPicker:
                            BackgroundPickerView(title: "Solid Colors", items: HomePage.Models.SettingsModel.SolidColor.allCases)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        case .gradientPicker:
                            BackgroundPickerView(title: "Gradients", items: HomePage.Models.SettingsModel.Gradient.allCases)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        case .illustrationPicker:
                            BackgroundPickerView(title: "Illustrations", items: HomePage.Models.SettingsModel.Illustration.allCases)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        case .customImagePicker:
                            BackgroundPickerView(title: "My Backgrounds", items: model.availableUserBackgroundImages) {
                                addBackgroundButton
                                Text("Images are stored on your device so DuckDuckGo can't see or access them.")
                                    .foregroundColor(.blackWhite60)
                                    .multilineTextAlignment(.leading)
                            }
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

        var header: some View {
            HStack(spacing: 0) {
                Text("Customize")
                    .font(.system(size: 17).bold())
                Spacer()
                CloseButton(icon: .closeLarge, size: 28) {
                    isSettingsVisible = false
                    model.popToRootView()
                }
            }
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
                model.popToRootView()
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
                SettingsGrid(items: model.customBackgroundModes) { mode in
                    BackgroundCategoryView(modeModel: mode) {
                        model.handleRootGridSelection(mode)
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
}

extension HomePage.Views.SettingsView {
    fileprivate typealias CloseButton = HomePage.Views.CloseButton
    fileprivate typealias SettingsSection = HomePage.Views.SettingsSection
    fileprivate typealias BackgroundThumbnailView = HomePage.Views.BackgroundThumbnailView
    fileprivate typealias BackgroundCategoryView = HomePage.Views.BackgroundCategoryView
}

extension HomePage.Views.BackgroundCategoryView {
    fileprivate typealias BackgroundThumbnailView = HomePage.Views.BackgroundThumbnailView
}

#Preview {
    @State var isSettingsVisible: Bool = true

    let model = HomePage.Models.SettingsModel(openSettings: {})
    model.customBackground = .solidColor(.lightPink)

    return HomePage.Views.SettingsView(includingContinueSetUpCards: true, isSettingsVisible: $isSettingsVisible)
        .frame(width: 236)
        .environmentObject(model)
}
