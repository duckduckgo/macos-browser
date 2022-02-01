//
//  PasswordManagementItemListView.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Foundation
import SwiftUI
import BrowserServicesKit

struct ScrollOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

struct PasswordManagementItemListView: View {

    @EnvironmentObject var model: PasswordManagementItemListModel
    
    @State private var opacity = CGFloat.zero

    var body: some View {

        if #available(macOS 11.0, *) {
            VStack(spacing: 0) {
                PasswordManagementItemListCategoryView()
                    .padding([.leading, .trailing], 15)
                    .padding([.top, .bottom], 15)
                
                Divider()
                    .opacity(opacity)
                
                GeometryReader { outsideProxy in
                ScrollView {
                    ScrollViewReader { proxy in
                        PasswordManagementItemListStackView()
                            .onAppear {
                                // Scrolling to the selected item doesn't work consistently without a very slight delay.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    if let selectionID = model.selected?.id {
                                        proxy.scrollTo(selectionID, anchor: .center)
                                    }
                                }
                            }
                            .background(GeometryReader { insideProxy in
                                Color.clear.preference(key: ScrollOffsetKey.self,
                                                       value: self.calculateContentOffset(fromOutsideProxy: outsideProxy, insideProxy: insideProxy))
                            })
                            .onPreferenceChange(ScrollOffsetKey.self) { offset in
                                if offset <= 0 {
                                    self.opacity = 0
                                } else {
                                    // Fade in the divider over 100pts of scrolling. This is picked arbitrarily, and can be changed.
                                    self.opacity = offset / 100
                                }
                            }
                    }
                }
                }
            }
        } else {
            PasswordManagementItemListStackView()
        }

    }
    
    private func calculateContentOffset(fromOutsideProxy outsideProxy: GeometryProxy, insideProxy: GeometryProxy) -> CGFloat {
        return outsideProxy.frame(in: .global).minY - insideProxy.frame(in: .global).minY
    }

}

struct PasswordManagementItemListCategoryView: View {
    
    @EnvironmentObject var model: PasswordManagementItemListModel

    var body: some View {
        
        HStack {
            
            // Category Picker:
            
            NSPopUpButtonView<SecureVaultSorting.Category>(selection: $model.sortDescriptor.category, viewCreator: {
                let button = NSPopUpButton()
                button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
                button.isBordered = false
                (button.cell as? NSPopUpButtonCell)?.arrowPosition = .arrowAtCenter
                
                for category in SecureVaultSorting.Category.allCases {
                    let item = button.menu?.addItem(withTitle: category.rawValue, action: nil, keyEquivalent: "")
                    item?.representedObject = category
                    
                    if category == .allItems {
                        button.menu?.addItem(NSMenuItem.separator())
                    }
                }
                
                button.sizeToFit()

                return button
            })
                .frame(maxHeight: 20)
            
            Spacer()

            // Sort Picker:

            MenuButton(label: Image(model.sortDescriptor.order == .ascending ? "SortAscending" : "SortDescending")) {
                Picker("", selection: $model.sortDescriptor.parameter) {
                    ForEach(SecureVaultSorting.SortParameter.allCases, id: \.self) {
                        if $0 == model.sortDescriptor.parameter {
                            Text("✓ \($0.rawValue)")
                        } else {
                            Text($0.rawValue)
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)

                Divider()

                Picker("", selection: $model.sortDescriptor.order) {
                    ForEach(SecureVaultSorting.SortOrder.allCases, id: \.self) {
                        if $0 == model.sortDescriptor.order {
                            Text("✓ \($0.title(for: model.sortDescriptor.parameter.type))")
                        } else {
                            Text($0.title(for: model.sortDescriptor.parameter.type))
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
            }
            .menuButtonStyle(BorderlessButtonMenuButtonStyle())
            .frame(width: 16, height: 16)

        }
        
    }
}

struct PasswordManagementItemListStackView: View {
    
    @EnvironmentObject var model: PasswordManagementItemListModel
    
    var body: some View {
        
        if #available(macOS 11.0, *) {
            LazyVStack(alignment: .leading) {
                PasswordManagementItemStackContentsView()
            }
        } else {
            VStack(alignment: .leading) {
                PasswordManagementItemStackContentsView()
            }
        }
        
    }
    
}

struct PasswordManagementItemListTableView: View {
    
    @EnvironmentObject var model: PasswordManagementItemListModel

    var body: some View {
        
        let _ = print("DEBUG: Selected: \(model.selected?.id)")

        List {
            ForEach(model.displayedItems, id: \.title) { section in
                Section(header: Text(section.title)) {
                    ForEach(section.items) { item in
                        ItemView(item: item, selected: model.selected == item) {
                            model.selected(item: item)
                        }
                    }
                }
            }
        }

    }
    
}

private struct PasswordManagementItemStackContentsView: View {
    
    @EnvironmentObject var model: PasswordManagementItemListModel

    var body: some View {
        Spacer(minLength: 10)
        
        ForEach(model.displayedItems, id: \.title) { section in
            
            Section(header: Text(section.title).padding(.leading, 18).padding(.top, 10)) {
                
                ForEach(section.items, id: \.id) { item in
                    ItemView(item: item, selected: model.selected == item) {
                        model.selected(item: item)
                    }
                    .padding(.horizontal, 10)
                }
            }
            
        }
        
        Spacer(minLength: 10)
    }
    
}

private struct ItemView: View {

    let item: SecureVaultItem
    let selected: Bool
    let action: () -> Void

    var body: some View {

        if selected {
            let _ = print("DEBUG: Got Selected: \(item.id)")
        }
        
        let textColor = selected ? .white : Color(NSColor.controlTextColor)
        let font = Font.custom("SFProText-Regular", size: 13)

        Button(action: action, label: {
            
            HStack(spacing: 0) {

                switch item {
                case .account(let account):
                    LoginFaviconView(domain: account.domain)
                        .padding(.leading, 6)
                case .card:
                    Image("Card")
                        .frame(width: 32)
                        .padding(.leading, 6)
                case .identity:
                    Image("Identity")
                        .frame(width: 32)
                        .padding(.leading, 6)
                case .note:
                    Image("Note")
                        .frame(width: 32)
                        .padding(.leading, 6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayTitle)
                        .foregroundColor(textColor)
                        .font(font)
                    Text(item.displaySubtitle)
                        .foregroundColor(textColor.opacity(0.8))
                        .font(font)
                }
                .padding(.leading, 4)
            }
        })
            .frame(maxHeight: 48)
            .buttonStyle(selected ?
                         PasswordManagerItemButtonStyle(bgColor: Color.accentColor) :
                            // Almost clear, so that whole view is clickable
                         PasswordManagerItemButtonStyle(bgColor: Color(NSColor.windowBackgroundColor.withAlphaComponent(0.001))))
    }

}

private struct PasswordManagerItemButtonStyle: ButtonStyle {

    let bgColor: Color

    func makeBody(configuration: Self.Configuration) -> some View {

        configuration.label
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .truncationMode(.tail)
            .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(bgColor))

    }
}
