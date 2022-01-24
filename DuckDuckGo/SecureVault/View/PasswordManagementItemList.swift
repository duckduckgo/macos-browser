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

struct PasswordManagementItemListView: View {

    @EnvironmentObject var model: PasswordManagementItemListModel
    @State private var timer = Timer.publish(every: 2, tolerance: 0, on: .main, in: .default, options: nil).autoconnect()

    var body: some View {

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
            PasswordManagementItemListStackView()
        }

    }

}

struct PasswordManagementItemListStackView: View {
    
    @EnvironmentObject var model: PasswordManagementItemListModel
    
    var body: some View {
        
        if #available(macOS 11.0, *) {
            LazyVStack(alignment: .leading) {
                PasswordManagementItemListInternalView()
            }
        } else {
            VStack(alignment: .leading) {
                PasswordManagementItemListInternalView()
            }
        }
        
    }
    
}

private struct PasswordManagementItemListInternalView: View {
    
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
