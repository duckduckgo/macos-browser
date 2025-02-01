//
//  PreferencesGeneralView.swift
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

import AppKit
import Combine
import FeatureFlags
import MaliciousSiteProtection
import PixelKit
import PreferencesUI_macOS
import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct GeneralView: View {
        @ObservedObject var startupModel: StartupPreferences
        @ObservedObject var downloadsModel: DownloadsPreferences
        @ObservedObject var searchModel: SearchPreferences
        @ObservedObject var tabsModel: TabsPreferences
        @ObservedObject var dataClearingModel: DataClearingPreferences
        @ObservedObject var maliciousSiteDetectionModel: MaliciousSiteProtectionPreferences
        @State private var showingCustomHomePageSheet = false
        @State private var isAddedToDock = false
        var dockCustomizer: DockCustomizer
        let featureFlagger = NSApp.delegateTyped.featureFlagger

        var body: some View {
            PreferencePane(UserText.general) {

                // SECTION 1: Shortcuts
#if !APPSTORE
                PreferencePaneSection(UserText.shortcuts, spacing: 4) {
                    PreferencePaneSubSection {
                        HStack {
                            if isAddedToDock || dockCustomizer.isAddedToDock {
                                HStack {
                                    Image(.checkCircle).foregroundColor(Color(.successGreen))
                                    Text(UserText.isAddedToDock)
                                }
                                .transition(.opacity)
                                .padding(.trailing, 8)
                            } else {
                                HStack {
                                    Image(.warning).foregroundColor(Color(.linkBlue))
                                    Text(UserText.isNotAddedToDock)
                                }
                                .padding(.trailing, 8)
                                Button(action: {
                                    withAnimation {
                                        PixelKit.fire(GeneralPixel.userAddedToDockFromSettings,
                                                      includeAppVersionParameter: false)
                                        dockCustomizer.addToDock()
                                        isAddedToDock = true
                                    }
                                }) {
                                    Text(UserText.addToDock)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }
                }
#endif
                // SECTION 2: On Startup
                PreferencePaneSection(UserText.onStartup) {

                    PreferencePaneSubSection {
                        Picker(selection: $startupModel.restorePreviousSession, content: {
                            Text(UserText.showHomePage).tag(false)
                                .padding(.bottom, 4).accessibilityIdentifier("PreferencesGeneralView.stateRestorePicker.openANewWindow")
                            Text(UserText.reopenAllWindowsFromLastSession).tag(true)
                                .accessibilityIdentifier("PreferencesGeneralView.stateRestorePicker.reopenAllWindowsFromLastSession")
                        }, label: {})
                        .pickerStyle(.radioGroup)
                        .disabled(dataClearingModel.isAutoClearEnabled)
                        .offset(x: PreferencesUI_macOS.Const.pickerHorizontalOffset)
                        .accessibilityIdentifier("PreferencesGeneralView.stateRestorePicker")
                        if dataClearingModel.isAutoClearEnabled {
                            VStack(alignment: .leading, spacing: 1) {
                                TextMenuItemCaption(UserText.disableAutoClearToEnableSessionRestore)
                                TextButton(UserText.showDataClearingSettings) {
                                    startupModel.show(url: .settingsPane(.dataClearing))
                                }
                            }
                            .padding(.leading, 19)
                        }
                    }
                }

                // SECTION 3: Tabs
                PreferencePaneSection(UserText.tabs) {
                    PreferencePaneSubSection {
                        ToggleMenuItem(UserText.preferNewTabsToWindows, isOn: $tabsModel.preferNewTabsToWindows)
                        ToggleMenuItem(UserText.switchToNewTabWhenOpened, isOn: $tabsModel.switchToNewTabWhenOpened)
                    }

                    PreferencePaneSubSection {
                        HStack {
                            Picker(UserText.newTabPositionTitle, selection: $tabsModel.newTabPosition) {
                                ForEach(NewTabPosition.allCases, id: \.self) { position in
                                    Text(UserText.newTabPositionMode(for: position)).tag(position)
                                }
                            }
                            .fixedSize()
                        }
                    }
                }

                // SECTION 4: Home Page
                PreferencePaneSection(UserText.homePage) {

                    PreferencePaneSubSection {

                        TextMenuItemCaption(UserText.homePageDescription)

                        Picker(selection: $startupModel.launchToCustomHomePage, label: EmptyView()) {
                            Text(UserText.newTab).tag(false)
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 15) {
                                    Text(UserText.specificPage)
                                    Button(UserText.setPage) {
                                        showingCustomHomePageSheet.toggle()
                                    }.disabled(!startupModel.launchToCustomHomePage)
                                }
                                TextMenuItemCaption(startupModel.friendlyURL)
                                    .padding(.top, 0)
                                    .visibility(!startupModel.launchToCustomHomePage ? .gone : .visible)

                            }.tag(true)
                        }
                        .pickerStyle(.radioGroup)
                        .offset(x: PreferencesUI_macOS.Const.pickerHorizontalOffset)
                    }

                    PreferencePaneSubSection {
                        HStack {
                            Picker(UserText.mainMenuHomeButton, selection: $startupModel.homeButtonPosition) {
                                ForEach(HomeButtonPosition.allCases, id: \.self) { position in
                                    Text(UserText.homeButtonMode(for: position)).tag(position)
                                }
                            }
                            .fixedSize()
                            .onChange(of: startupModel.homeButtonPosition) { _ in
                                startupModel.updateHomeButton()
                            }
                        }
                    }

                }.sheet(isPresented: $showingCustomHomePageSheet) {
                    CustomHomePageSheet(startupModel: startupModel, isSheetPresented: $showingCustomHomePageSheet)
                }

                // SECTION 5: Search Settings
                PreferencePaneSection(UserText.privateSearch) {
                    ToggleMenuItem(UserText.showAutocompleteSuggestions, isOn: $searchModel.showAutocompleteSuggestions).accessibilityIdentifier("PreferencesGeneralView.showAutocompleteSuggestions")
                }

                // SECTION 6: Downloads
                PreferencePaneSection(UserText.downloads) {
                    PreferencePaneSubSection {
                        ToggleMenuItem(UserText.downloadsOpenPopupOnCompletion,
                                       isOn: $downloadsModel.shouldOpenPopupOnCompletion)
                    }.padding(.bottom, 5)

                    // MARK: Location
                    PreferencePaneSubSection {
                        Text(UserText.downloadsLocation).bold()

                        HStack {
                            NSPathControlView(url: downloadsModel.selectedDownloadLocation)
                            Button(UserText.downloadsChangeDirectory) {
                                downloadsModel.presentDownloadDirectoryPanel()
                            }
                        }
                        .disabled(downloadsModel.alwaysRequestDownloadLocation)

                        ToggleMenuItem(UserText.downloadsAlwaysAsk,
                                       isOn: $downloadsModel.alwaysRequestDownloadLocation).accessibilityIdentifier("PreferencesGeneralView.alwaysAskWhereToSaveFiles")
                    }
                }

                // SECTION 7: Phishing Detection
                if featureFlagger.maliciousSiteProtectionFeatureFlags().isMaliciousSiteProtectionEnabled {
                    PreferencePaneSection(UserText.maliciousSiteDetectionHeader, spacing: 0) {
                        PreferencePaneSubSection {
                            ToggleMenuItem(UserText.maliciousSiteDetectionIsEnabled,
                                           isOn: $maliciousSiteDetectionModel.isEnabled)
                            .onChange(of: maliciousSiteDetectionModel.isEnabled) { newValue in
                                PixelKit.fire(MaliciousSiteProtection.Event.settingToggled(to: newValue))
                            }
                        }
                        TextButton(UserText.learnMore) {
                            tabsModel.openNewTab(with: .maliciousSiteProtectionLearnMore)
                        }
                        .padding(.leading, 19)
                        .padding(.top, 0)

                        Text(UserText.maliciousDetectionEnabledWarning)
                            .opacity(maliciousSiteDetectionModel.isEnabled ? 0 : 1)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.leading, 19)
                            .padding(.top, 5)
                    }
                }
            }
        }
    }
}

struct CustomHomePageSheet: View {

    @ObservedObject var startupModel: StartupPreferences
    @State var url: String = ""
    @State var isValidURL: Bool = true
    @Binding var isSheetPresented: Bool

    var body: some View {
        VStack(alignment: .center) {
            TextMenuTitle(UserText.setHomePage)
                .padding(.vertical, 10)

            Group {
                HStack {
                    Text(UserText.addressLabel)
                        .padding(.trailing, 10)
                    TextField("", text: $url)
                        .frame(width: 250)
                        .onChange(of: url) { newValue in
                            validateURL(newValue)
                        }
                }
                .padding(8)
            }
            .roundedBorder()
            .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))

            Divider()

            HStack(alignment: .center) {
                Spacer()
                Button(UserText.cancel) {
                    isSheetPresented.toggle()
                }
                Button(UserText.save) {
                    saveChanges()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValidURL)
            }.padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 15))

        }
        .padding(.vertical, 10)
        .onAppear(perform: {
            url = startupModel.customHomePageURL
        })
    }

    private func saveChanges() {
        startupModel.customHomePageURL = url
        isSheetPresented.toggle()
    }

    private func validateURL(_ url: String) {
        isValidURL = startupModel.isValidURL(url)
    }
}
