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
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 15).weight(.semibold))
                content()
            }
        }
    }

}
