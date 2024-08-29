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

    /**
     * This view displays array of items in a grid with 2 columns.
     */
    struct SettingsGrid<Item, ItemView>: View where Item: Identifiable & Hashable, ItemView: View {

        let items: [Item]
        @ViewBuilder let itemView: (Item) -> ItemView

        var body: some View {
            if #available(macOS 12.0, *), items.count > 1 {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: SettingsView.Const.gridItemSpacing),
                        count: 2
                    ),
                    spacing: SettingsView.Const.gridItemSpacing
                ) {
                    ForEach(items, content: itemView)
                }
            } else {
                let rows = items.chunked(into: 2)
                VStack(alignment: .leading, spacing: SettingsView.Const.gridItemSpacing) {
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: SettingsView.Const.gridItemSpacing) {
                            ForEach(row) { row in
                                itemView(row).frame(width: SettingsView.Const.gridItemWidth)
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

    /**
     * This view displays array of items in a grid with 2 columns, and optionally displays customizable placeholder items.
     */
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

        /**
         * This closure provides a view for a given item.
         *
         * If `item` parameter is `nil`, the closure should build a placeholder view.
         */
        @ViewBuilder let itemView: (Item?) -> ItemView

        /**
         * If `items` has fewer elements than `expectedMaxNumberOfItems`, it's padded with placeholder items
         * up to `expectedMaxNumberOfItems` items. If `items` has as many elements as the value of
         * `expectedMaxNumberOfItems` or more, no placeholders are displayed.
         */
        init(items: [Item], expectedMaxNumberOfItems: Int, @ViewBuilder itemView: @escaping (Item?) -> ItemView) {
            var allItems = items.map(ItemOrPlaceholder.item)
            if expectedMaxNumberOfItems > allItems.count {
                for index in allItems.count..<expectedMaxNumberOfItems {
                    allItems.append(.placeholder(index))
                }
            }
            self.items = allItems
            self.itemView = itemView
        }

        var body: some View {
            if #available(macOS 12.0, *), items.count > 1 {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: SettingsView.Const.gridItemSpacing),
                        count: 2
                    ),
                    spacing: SettingsView.Const.gridItemSpacing
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
                VStack(alignment: .leading, spacing: SettingsView.Const.gridItemSpacing) {
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: SettingsView.Const.gridItemSpacing) {
                            ForEach(row) { row in
                                if case .item(let item) = row {
                                    itemView(item).frame(width: SettingsView.Const.gridItemWidth)
                                } else {
                                    itemView(nil).frame(width: SettingsView.Const.gridItemWidth)
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
