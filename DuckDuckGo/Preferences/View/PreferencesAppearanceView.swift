//
//  PreferencesAppearanceView.swift
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

import Bookmarks
import PreferencesUI_macOS
import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct ThemeButton: View {
        let title: String
        let imageName: String
        @Binding var isSelected: Bool

        var body: some View {
            VStack {
                Button(action: { isSelected.toggle() }) {
                    VStack(spacing: 2) {
                        Image(imageName)
                            .padding(2)
                            .background(selectionBackground)
                        Text(title)
                    }
                }
                .padding(.horizontal, 2)
                .buttonStyle(.plain)
            }
        }

        @ViewBuilder
        private var selectionBackground: some View {
            if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.linkBlue), lineWidth: 2)
            }
        }

    }

    struct ThemePicker: View {
        @EnvironmentObject var model: AppearancePreferences

        var body: some View {
            HStack(spacing: 24) {
                ForEach(ThemeName.allCases, id: \.self) { theme in
                    ThemeButton(
                        title: theme.displayName,
                        imageName: theme.imageName,
                        isSelected: isThemeSelected(theme)
                    )
                }
            }
        }

        private func isThemeSelected(_ theme: ThemeName) -> Binding<Bool> {
            .init(
                get: {
                    model.currentThemeName == theme
                },
                set: { isSelected in
                    if isSelected {
                        model.currentThemeName = theme
                    }
                }
            )
        }
    }

    struct AppearanceView: View {
        @ObservedObject var model: AppearancePreferences
        @ObservedObject var addressBarModel: HomePage.Models.AddressBarModel

        var body: some View {
            PreferencePane(UserText.appearance) {

                // SECTION 1: Theme
                PreferencePaneSection(UserText.theme) {

                    ThemePicker()
                        .environmentObject(model)
                }

                // SECTION 2: Address Bar
                PreferencePaneSection(UserText.addressBar) {
                    ToggleMenuItem(UserText.showFullWebsiteAddress, isOn: $model.showFullURL)
                }

                // SECTION 3: New Tab Page
                PreferencePaneSection(UserText.newTabBottomPopoverTitle) {

                    PreferencePaneSubSection {
                        if addressBarModel.shouldShowAddressBar {
                            ToggleMenuItem(UserText.newTabSearchBarSectionTitle, isOn: $model.isSearchBarVisible)
                        }
                        if model.isContinueSetUpCardsVisibilityControlAvailable && model.isContinueSetUpAvailable && !model.isContinueSetUpCardsViewOutdated && !model.continueSetUpCardsClosed {
                            ToggleMenuItem(UserText.newTabSetUpSectionTitle, isOn: $model.isContinueSetUpVisible)
                        }
                        ToggleMenuItem(UserText.newTabFavoriteSectionTitle, isOn: $model.isFavoriteVisible).accessibilityIdentifier("Preferences.AppearanceView.showFavoritesToggle")
                        if model.isRecentActivityAvailable {
                            ToggleMenuItem(UserText.newTabRecentActivitySectionTitle, isOn: $model.isRecentActivityVisible)
                        }
                        if model.isPrivacyStatsAvailable {
                            ToggleMenuItem(UserText.newTabPrivacyStatsSectionTitle, isOn: $model.isPrivacyStatsVisible)
                        }
                    }

                    PreferencePaneSubSection {

                        Button {
                            model.openNewTabPageBackgroundCustomizationSettings()
                        } label: {
                            HStack {
                                Text(UserText.customizeBackground)
                                Image(.externalAppScheme)
                            }
                            .foregroundColor(Color.linkBlue)
                            .cursor(.pointingHand)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // SECTION 4: Bookmarks Bar
                PreferencePaneSection(UserText.showBookmarksBar) {
                    HStack {
                        ToggleMenuItem(UserText.showBookmarksBarPreference, isOn: $model.showBookmarksBar)
                            .accessibilityIdentifier("Preferences.AppearanceView.showBookmarksBarPreferenceToggle")
                        NSPopUpButtonView(selection: $model.bookmarksBarAppearance) {
                            let button = NSPopUpButton()
                            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
                            button.setAccessibilityIdentifier("Preferences.AppearanceView.showBookmarksBarPopUp")

                            let alwaysOn = button.menu?.addItem(withTitle: UserText.showBookmarksBarAlways, action: nil, keyEquivalent: "")
                            alwaysOn?.representedObject = BookmarksBarAppearance.alwaysOn
                            alwaysOn?.setAccessibilityIdentifier("Preferences.AppearanceView.showBookmarksBarAlways")

                            let newTabOnly = button.menu?.addItem(withTitle: UserText.showBookmarksBarNewTabOnly, action: nil, keyEquivalent: "")
                            newTabOnly?.representedObject = BookmarksBarAppearance.newTabOnly
                            newTabOnly?.setAccessibilityIdentifier("Preferences.AppearanceView.showBookmarksBarNewTabOnly")

                            return button
                        }
                        .disabled(!model.showBookmarksBar)
                    }

                    HStack {
                        Text(UserText.preferencesBookmarksCenterAlignBookmarksBarTitle)
                        NSPopUpButtonView(selection: $model.centerAlignedBookmarksBarBool) {
                            let button = NSPopUpButton()
                            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)

                            let leftAligned = button.menu?.addItem(withTitle: UserText.preferencesBookmarksLeftAlignBookmarksBare, action: nil, keyEquivalent: "")
                            leftAligned?.representedObject = false

                            let centerAligned = button.menu?.addItem(withTitle: UserText.preferencesBookmarksCenterAlignBookmarksBar, action: nil, keyEquivalent: "")
                            centerAligned?.representedObject = true

                            return button
                        }
                    }
                }
            }
        }
    }
}
