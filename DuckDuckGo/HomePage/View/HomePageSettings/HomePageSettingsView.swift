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

struct CustomColorPicker: NSViewRepresentable {
    @Binding var selectedColor: Color
    var label: String
    var previewSize: NSSize

    func makeNSView(context: Context) -> CustomNSColorWell {
        let colorWell = CustomNSColorWell(frame: .zero)
        colorWell.color = NSColor(selectedColor)
        colorWell.customPreviewSize = previewSize
        colorWell.target = context.coordinator
        colorWell.action = #selector(Coordinator.colorChanged(_:))
        return colorWell
    }

    func updateNSView(_ nsView: CustomNSColorWell, context: Context) {
        nsView.color = NSColor(selectedColor)
        nsView.customPreviewSize = previewSize
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject {
        var parent: CustomColorPicker

        init(_ parent: CustomColorPicker) {
            self.parent = parent
        }

        @objc func colorChanged(_ sender: NSColorWell) {
            parent.selectedColor = Color(sender.color)
        }
    }
}

final class CustomNSColorWell: NSColorWell {
    var customPreviewSize: NSSize = NSSize(width: 44, height: 44)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        color.setFill()
        dirtyRect.fill()
    }

    override var intrinsicContentSize: NSSize {
        return customPreviewSize
    }
}

extension HomePage.Views {

    struct SettingsView: View {

        enum Const {
            static let gridItemWidth = 96.0
            static let gridItemHeight = 64.0
            static let gridItemSpacing = 12.0
            static let viewWidth = 204.0
            static let viewPadding = 16.0
            static let headerSpacing = 24.0
            static let sectionSpacing = 36.0
        }

        let includingContinueSetUpCards: Bool
        @EnvironmentObject var model: HomePage.Models.SettingsModel
        @EnvironmentObject var appearancePreferences: AppearancePreferences
        @EnvironmentObject var continueSetUpModel: HomePage.Models.ContinueSetUpModel
        @EnvironmentObject var favoritesModel: HomePage.Models.FavoritesModel

        @Binding var isSettingsVisible: Bool

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Const.headerSpacing) {

                    header

                    VStack(alignment: .leading, spacing: Const.sectionSpacing) {
                        switch model.contentType {
                        case .root:
                            rootView
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        case .colorPicker:
                            BackgroundPickerView(title: UserText.solidColors, items: model.solidColorPickerItems, itemView: { item in
                                switch item {
                                case .background:
                                    defaultItemView(for: item)
                                case .picker:
                                    Button {
                                        withAnimation {
                                            if model.customBackground != item.customBackground {
                                                model.customBackground = item.customBackground
                                            }
                                        }
                                        model.openColorPanel()
                                    } label: {
                                        ZStack {
                                            BackgroundThumbnailView(displayMode: .pickerView, customBackground: item.customBackground)
                                            Image(.colorPicker)
                                                .opacity(0.8)
                                                .colorScheme(item.customBackground.colorScheme)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            })
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .onDisappear {
                                model.onColorPickerDisappear()
                            }
                        case .gradientPicker:
                            BackgroundPickerView(title: UserText.gradients, items: GradientBackground.allCases, itemView: defaultItemView(for:))
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        case .customImagePicker:
                            BackgroundPickerView(
                                title: UserText.myBackgrounds,
                                items: model.availableUserBackgroundImages,
                                maxItemsCount: HomePage.Models.SettingsModel.Const.maximumNumberOfUserImages,
                                itemView: defaultItemView(for:),
                                footer: {
                                    addBackgroundButton
                                    Text(UserText.myBackgroundsDisclaimer)
                                        .foregroundColor(.blackWhite60)
                                        .multilineTextAlignment(.leading)
                                })
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.none, value: model.customBackground)

                    Spacer()
                }
                .frame(width: Const.viewWidth)
                .padding(Const.viewPadding)
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
                Text(UserText.homePageSettingsTitle)
                    .font(.system(size: 17).bold())
                Spacer()
                CloseButton(icon: .closeLarge, size: 28) {
                    isSettingsVisible = false
                    model.popToRootView()
                }
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
        func defaultItemView(for item: any Identifiable & Hashable & CustomBackgroundConvertible) -> some View {
            Button {
                withAnimation {
                    if model.customBackground != item.customBackground {
                        model.customBackground = item.customBackground
                    }
                }
            } label: {
                BackgroundThumbnailView(displayMode: .pickerView, customBackground: item.customBackground)
            }
            .buttonStyle(.plain)
        }

        @ViewBuilder
        var rootView: some View {
            SettingsSection(title: UserText.background) {
                SettingsGrid(items: model.customBackgroundModes) { mode in
                    BackgroundCategoryView(modeModel: mode) {
                        model.handleRootGridSelection(mode)
                    }
                }
                TextButton(UserText.resetBackground) {
                    withAnimation {
                        model.customBackground = nil
                    }
                }
            }
            .animation(.none, value: model.customBackground)
            SettingsSection(title: UserText.browserTheme) {
                ThemePicker()
            }
            SettingsSection(title: UserText.homePageSections) {
                HomeContentSectionsView(includeContinueSetUpCards: includingContinueSetUpCards)
            }
            rootViewFooter
        }

        var rootViewFooter: some View {
            VStack(spacing: 18) {
                Divider()

                Button {
                    model.openSettings()
                } label: {
                    HStack {
                        Text(UserText.allSettings)
                        Spacer()
                        Image(.externalAppScheme)
                    }
                    .foregroundColor(Color.linkBlue)
                    .cursor(.pointingHand)
                }
                .buttonStyle(.plain)
            }
        }

        @ViewBuilder
        var addBackgroundButton: some View {
            let button = Button {
                Task {
                    await model.addNewImage()
                }
            } label: {
                Text(UserText.addBackground)
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

// The extensions below are required for the preview to work

extension HomePage.Views.SettingsView {
    fileprivate typealias BackgroundCategoryView = HomePage.Views.BackgroundCategoryView
    fileprivate typealias BackgroundPickerView = HomePage.Views.BackgroundPickerView
    fileprivate typealias BackgroundThumbnailView = HomePage.Views.BackgroundThumbnailView
    fileprivate typealias CloseButton = HomePage.Views.CloseButton
    fileprivate typealias HomeContentSectionsView = HomePage.Views.HomeContentSectionsView
    fileprivate typealias SettingsGrid = HomePage.Views.SettingsGrid
    fileprivate typealias SettingsGridWithPlaceholders = HomePage.Views.SettingsGridWithPlaceholders
    fileprivate typealias SettingsSection = HomePage.Views.SettingsSection
    fileprivate typealias ThemePicker = HomePage.Views.ThemePicker
}

extension HomePage.Views.BackgroundCategoryView {
    fileprivate typealias BackgroundThumbnailView = HomePage.Views.BackgroundThumbnailView
}

#Preview {
    @State var isSettingsVisible: Bool = true

    let model = HomePage.Models.SettingsModel(openSettings: {})
    model.customBackground = .solidColor(.color10)

    return HomePage.Views.SettingsView(includingContinueSetUpCards: true, isSettingsVisible: $isSettingsVisible)
        .frame(width: 236, height: 600)
        .environmentObject(model)
        .environmentObject(AppearancePreferences.shared)
        .environmentObject(HomePage.Models.ContinueSetUpModel(
            defaultBrowserProvider: SystemDefaultBrowserProvider(),
            dockCustomizer: DockCustomizer(),
            dataImportProvider: BookmarksAndPasswordsImportStatusProvider(),
            tabCollectionViewModel: TabCollectionViewModel(),
            duckPlayerPreferences: DuckPlayerPreferencesUserDefaultsPersistor()
        ))
        .environmentObject(HomePage.Models.FavoritesModel(
            open: { _, _ in },
            removeFavorite: { _ in },
            deleteBookmark: { _ in },
            add: {},
            edit: { _ in },
            moveFavorite: { _, _ in },
            onFaviconMissing: {}
        ))
}
