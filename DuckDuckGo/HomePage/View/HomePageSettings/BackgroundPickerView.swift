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

    struct BackgroundPickerView<Item, ItemView, FooterView>: View where Item: Identifiable & Hashable & CustomBackgroundConvertible,
                                                                        ItemView: View,
                                                                        FooterView: View {

        let title: String
        let items: [Item]
        let maxItemsCount: Int
        @ViewBuilder let itemView: (Item) -> ItemView
        @ViewBuilder let footer: () -> FooterView

        init(
            title: String,
            items: [Item],
            maxItemsCount: Int = 0,
            @ViewBuilder itemView: @escaping (Item) -> ItemView,
            @ViewBuilder footer: @escaping () -> FooterView = { EmptyView() }
        ) {
            self.title = title
            self.items = items
            self.maxItemsCount = maxItemsCount
            self.itemView = itemView
            self.footer = footer
        }

        @EnvironmentObject var model: HomePage.Models.SettingsModel

        var body: some View {
            VStack(spacing: 16) {
                backButton
                if items.count < maxItemsCount {
                    SettingsGridWithPlaceholders(items: items, expectedMaxNumberOfItems: maxItemsCount) { item in
                        if let item {
                            itemView(item)
                        } else {
                            Button {
                                Task {
                                    await model.addNewImage()
                                }
                            } label: {
                                BackgroundThumbnailView(displayMode: .addBackground)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    SettingsGrid(items: items, itemView: itemView)
                }
                footer()
            }
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
