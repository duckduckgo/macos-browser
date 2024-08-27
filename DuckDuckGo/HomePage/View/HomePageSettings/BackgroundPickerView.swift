//
//  BackgroundPickerView.swift
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

    struct BackgroundPickerView<Item, ContentView>: View where Item: Identifiable & Hashable & CustomBackgroundConvertible, ContentView: View {

        let title: String
        let items: [Item]
        let maxItemsCount: Int
        @ViewBuilder let footer: () -> ContentView

        init(title: String, items: [Item], maxItemsCount: Int = 0, @ViewBuilder footer: @escaping () -> ContentView = { EmptyView() }) {
            self.title = title
            self.items = items
            self.maxItemsCount = maxItemsCount
            self.footer = footer
        }

        @EnvironmentObject var model: HomePage.Models.SettingsModel

        var body: some View {
            VStack(spacing: 16) {
                backButton
                if items.count < maxItemsCount {
                    SettingsGridWithPlaceholders(items: items, maxNumberOfItems: maxItemsCount) { item in
                        if let item {
                            itemView(for: item)
                        } else {
                            Button {
                                Task {
                                    await model.addNewImage()
                                }
                            } label: {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(.homeFavoritesGhost), style: StrokeStyle(lineWidth: 1.5, dash: [4.0, 2.0]))
                                    .frame(height: 64)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    SettingsGrid(items: items, itemView: itemView(for:))
                }
                footer()
            }
        }

        @ViewBuilder
        func itemView(for item: Item) -> some View {
            Button {
                withAnimation {
                    if model.customBackground != item.customBackground {
                        model.customBackground = item.customBackground
                    }
                }
            } label: {
                BackgroundThumbnailView(customBackground: item.customBackground)
            }
            .buttonStyle(.plain)
        }

        @ViewBuilder
        var backButton: some View {
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
    }
}
