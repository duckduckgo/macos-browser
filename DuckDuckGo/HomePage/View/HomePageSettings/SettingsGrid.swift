//
//  SettingsGrid.swift
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

    struct SettingsGrid<Item, ItemView>: View where Item: Identifiable & Hashable, ItemView: View {

        let items: [Item]
        @ViewBuilder let itemView: (Item) -> ItemView

        var body: some View {
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

    struct SettingsGridWithPlaceholders<Item, ItemView>: View where Item: Identifiable & Hashable, ItemView: View {

        enum ItemOrPlaceholder<I>: Identifiable & Hashable where I: Identifiable & Hashable {
            case item(I)
            case placeholder(Int)

            var id: Int {
                switch self {
                case .item(let item):
                    return item.id.hashValue
                case .placeholder(let index):
                    return index.hashValue
                }
            }
        }

        let items: [ItemOrPlaceholder<Item>]
        let maxNumberOfItems: Int
        @ViewBuilder let itemView: (Item?) -> ItemView

        init(items: [Item], maxNumberOfItems: Int, @ViewBuilder itemView: @escaping (Item?) -> ItemView) {
            var allItems = items.map(ItemOrPlaceholder.item)
            if maxNumberOfItems > allItems.count {
                for index in allItems.count..<maxNumberOfItems {
                    allItems.append(.placeholder(index))
                }
            }
            self.items = allItems
            self.maxNumberOfItems = maxNumberOfItems
            self.itemView = itemView
        }

        var body: some View {
            if #available(macOS 12.0, *), items.count > 1 {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12), count: 2),
                    spacing: 12
                ) {
                    ForEach(items, content: { item in
                        if case .item(let item) = item {
                            itemView(item)
                        } else {
                            itemView(nil)
                        }
                    })
                }
            } else {
                let rows = items.chunked(into: 2)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row) { row in
                                if case .item(let item) = row {
                                    itemView(item).frame(width: 96)
                                } else {
                                    itemView(nil).frame(width: 96)
                                }
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
}
