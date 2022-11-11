//
//  PasswordManagementItemList.swift
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
import Combine

struct ScrollOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

struct PasswordManagementItemListView: View {

    private enum Constants {
        static let dividerFadeInDistance: CGFloat = 100
    }
 
    @EnvironmentObject var model: PasswordManagementItemListModel
    
    var body: some View {
        
        VStack(spacing: 0) {
            PasswordManagementItemListCategoryView()
                .padding(.top, 15)
                .padding(.bottom, 14)
                .padding([.leading, .trailing], 10)
                .disabled(!model.canChangeCategory)
                .opacity(model.canChangeCategory ? 1.0 : 0.5)
            
            Divider()
            
            if #available(macOS 11.0, *) {
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
                    }
                }
            } else {
                ScrollView {
                    PasswordManagementItemListStackView()
                }
            }
        }
    }

}

struct PasswordManagementItemListCategoryView: View {
    
    @EnvironmentObject var model: PasswordManagementItemListModel

    var body: some View {
        
        HStack(alignment: .center) {
            
            NSPopUpButtonView<SecureVaultSorting.Category>(selection: $model.sortDescriptor.category, viewCreator: {
                let button = PopUpButton()
                
                for category in SecureVaultSorting.Category.allCases {
                    button.addItem(withTitle: category.title,
                                   foregroundColor: category.foregroundColor,
                                   backgroundColor: category.backgroundColor)
                    
                    if let imageName = category.imageName {
                        button.lastItem?.image = NSImage(named: imageName)
                    }
                    
                    button.lastItem?.representedObject = category
                    
                    if category == .allItems {
                        button.menu?.addItem(NSMenuItem.separator())
                    }
                }
                
                button.sizeToFit()
                
                return button
            })
                .alignmentGuide(VerticalAlignment.center) { _ in
                    // Magic number to line up the pop up button with the sort button.
                    // The custom pop up button cell isn't getting the expected frame, making it look misaligned, so this is used
                    // to account for it.
                    return 11
                }
            
            Spacer()

            // MenuButton incorrectly displays a disabled state when you re-render it with a different image.
            // According to Stack Overflow, this was fixed in macOS 12, but it can still be reproduced on 12.2.
            // This also happens with Menu in macOS 11.0+, so using that on later macOS versions doesn't help.
            // To work around this, two separate buttons are used depending on the sort order. But, to make matters worse: this hack doesn't always work!
            // So, as a last resort, both buttons are kept in a ZStack with their image and opacity is used to determine whether they're visible, which so far seems reliable.
            //
            // Reference: https://stackoverflow.com/questions/65602163/swiftui-menu-button-displayed-as-disabled-initially
            
            if model.sortDescriptor.order == .ascending {
                PasswordManagementSortButton(imageName: "SortAscending")
            } else {
                PasswordManagementSortButton(imageName: "SortDescending")
            }
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

private struct ExternalPasswordManagerItemSection: View {
    @ObservedObject var model: PasswordManagementItemListModel
    
    var body: some View {
        Section(header: Text("Password Manager").padding(.leading, 18).padding(.top, 0)) {
            PasswordManagerItemView(model: model) {
                model.externalPasswordManagerSelected = true
            }
            .padding(.horizontal, 10)
        }
    }
}

private struct PasswordManagementItemStackContentsView: View {
    
    @EnvironmentObject var model: PasswordManagementItemListModel

    private var shouldDisplayExternalPasswordManagerRow: Bool {
        model.passwordManagerCoordinator.isEnabled &&
        (model.sortDescriptor.category == .allItems || model.sortDescriptor.category == .logins)
    }
    
    var body: some View {
        Spacer(minLength: 10)
        
        if shouldDisplayExternalPasswordManagerRow {
            ExternalPasswordManagerItemSection(model: model)
        }
        
        ForEach(Array(model.displayedItems.enumerated()), id: \.offset) { index, section in
            Section(header: Text(section.title).padding(.leading, 18).padding(.top, index == 0 ? 0 : 10)) {
                
                ForEach(section.items, id: \.id) { item in
                    ItemView(item: item) {
                        model.selected(item: item)
                    }
                    .padding(.horizontal, 10)
                }
            }
        }
        Spacer(minLength: 10)
    }
    
}

private struct PasswordManagerItemView: View {
    @ObservedObject var model: PasswordManagementItemListModel
    
    let action: () -> Void
    
    private var isLocked: Bool {
        model.passwordManagerCoordinator.isLocked
    }
    
    private var lockStatusLabel: String {
        isLocked ? UserText.passwordManagerLockedStatus : UserText.passwordManagerUnlockedStatus
    }
    
    private var selected: Bool {
        model.externalPasswordManagerSelected
    }
    
    var body: some View {
        let textColor = selected ? .white : Color(NSColor.controlTextColor)
        let font = Font.custom("SFProText-Regular", size: 13)

        Button(action: action, label: {
            HStack(spacing: 3) {
                ZStack {
                    Image("BitwardenIcon")
                    
                    if isLocked {
                        Image("PasswordManager-lock")
                            .padding(.leading, 28)
                            .padding(.top, 21)
                    }
                    
                }.frame(width: 32)
                    .padding(.leading, 6)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.passwordManagerCoordinator.displayName)
                        .foregroundColor(textColor)
                        .font(font)
                    Text(lockStatusLabel)
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

private struct ItemView: View {

    @EnvironmentObject var model: PasswordManagementItemListModel

    let item: SecureVaultItem
    let action: () -> Void

    var body: some View {
 
        let selected = model.selected == item
        let textColor = selected ? .white : Color(NSColor.controlTextColor)
        let font = Font.custom("SFProText-Regular", size: 13)

        Button(action: action, label: {
            HStack(spacing: 2) {

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
                    switch item {
                    case .note:
                        Text(item.displayTitle)
                            .foregroundColor(textColor.opacity(0.7))
                            .font(font)
                        Text(item.displaySubtitle)
                            .foregroundColor(textColor.opacity(0.5))
                            .font(font)
                    default:
                        Text(item.displayTitle)
                            .foregroundColor(textColor)
                            .font(font)
                        Text(item.displaySubtitle)
                            .foregroundColor(textColor.opacity(0.8))
                            .font(font)
                    }
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

struct PasswordManagementSortButton: View {
    
    @EnvironmentObject var model: PasswordManagementItemListModel

    @State var sortHover: Bool = false
    
    let imageName: String
    
    var body: some View {
        
        ZStack {
            Image(imageName)
            
            // The image is added elsewhere, because MenuButton has a bug with using Images as labels.
            MenuButton(label: Image(nsImage: NSImage())) {
                Picker("", selection: $model.sortDescriptor.parameter) {
                    ForEach(SecureVaultSorting.SortParameter.allCases, id: \.self) { parameter in
                        Text(menuTitle(for: parameter.title, checked: parameter == model.sortDescriptor.parameter))
                    }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
                
                Divider()
                
                Picker("", selection: $model.sortDescriptor.order) {
                    ForEach(SecureVaultSorting.SortOrder.allCases, id: \.self) { order in
                        let orderTitle = order.title(for: model.sortDescriptor.parameter.type)
                        let labelTitle = menuTitle(for: orderTitle, checked: order == model.sortDescriptor.order)
                        Text(labelTitle)
                    }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
            }
            .menuButtonStyle(BorderlessButtonMenuButtonStyle())
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 5).foregroundColor(sortHover ? Color("SecureVaultCategoryDefaultColor") : Color.clear))
            .onHover { isOver in
                sortHover = isOver
            }
            .foregroundColor(.red)
        }
        
    }
    
    // The SwiftUI MenuButton view doesn't allow pickers which have checkmarks at the top level; they get put into a submenu.
    // This title is used in place of a nested picker.
    private func menuTitle(for string: String, checked: Bool) -> String {
        if checked {
            return "✓ \(string)"
        } else {
            return "    \(string)"
        }
    }
    
}
