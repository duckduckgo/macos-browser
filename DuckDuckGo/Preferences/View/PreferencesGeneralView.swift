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
import PreferencesViews
import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct GeneralView: View {
        @ObservedObject var defaultBrowserModel: DefaultBrowserPreferences
        @ObservedObject var startupModel: StartupPreferences
        @State private var showingCustomHomePageSheet = false

        var body: some View {
            PreferencePane(UserText.general) {

                // SECTION 1: Default Browser
                PreferencePaneSection(UserText.defaultBrowser) {

                    PreferencePaneSubSection {
                        HStack {
                            if defaultBrowserModel.isDefault {
                                Image(.solidCheckmark)
                                Text(UserText.isDefaultBrowser)
                            } else {
                                Image(.warning).foregroundColor(Color(.linkBlue))
                                Text(UserText.isNotDefaultBrowser)
                                Button(action: {
                                    defaultBrowserModel.becomeDefault()
                                }) {
                                    Text(UserText.makeDefaultBrowser)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }

                // SECTION 2: On Startup
                PreferencePaneSection(UserText.onStartup) {

                    PreferencePaneSubSection {
                        Picker(selection: $startupModel.restorePreviousSession, content: {
                            Text(UserText.showHomePage).tag(false)
                                .padding(.bottom, 4)
                            Text(UserText.reopenAllWindowsFromLastSession).tag(true)
                        }, label: {})
                        .pickerStyle(.radioGroup)
                        .offset(x: PreferencesViews.Const.pickerHorizontalOffset)
                    }
                }

                // SECTION 3: Home Page
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
                        .offset(x: PreferencesViews.Const.pickerHorizontalOffset)
                    }

                    PreferencePaneSubSection {
                        HStack {
                            Picker(UserText.mainMenuHomeButton, selection: $startupModel.homeButtonPosition) {
                                ForEach(HomeButtonPosition.allCases, id: \.self) { position in
                                    Text(UserText.homeButtonMode(for: position)).tag(position)
                                }
                            }
                            .scaledToFit()
                            .onChange(of: startupModel.homeButtonPosition) { _ in
                                startupModel.updateHomeButton()
                            }
                        }
                    }

                }.sheet(isPresented: $showingCustomHomePageSheet) {
                    CustomHomePageSheet(startupModel: startupModel, isSheetPresented: $showingCustomHomePageSheet)
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
