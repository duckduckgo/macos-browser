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

    var body: some View {

        List(model.displayedAccounts, id: \.id) { account in

            ItemView(account: account, selected: model.selected?.id) {
                model.selectAccount(account)
            }

        }
        .listStyle(SidebarListStyle())

    }

}

private struct ItemView: View {

    let account: SecureVaultModels.WebsiteAccount
    var selected: Int64?
    let action: () -> Void

    var body: some View {

        let selectedTextColor = Color(NSColor.selectedControlTextColor)

        Button(action: action, label: {
            HStack(spacing: 4) {
                FaviconView(domain: account.domain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.domain).bold()
                        .foregroundColor(selected == account.id ? selectedTextColor : nil)
                    Text(account.username)
                        .foregroundColor(selected == account.id ? selectedTextColor : nil)
                }
            }
        })
        .buttonStyle(selected == account.id ?
                        CustomButtonStyle(bgColor: Color(NSColor.selectedControlColor)) :
                        // Almost clear, so that whole view is clickable
                        CustomButtonStyle(bgColor: Color(NSColor.windowBackgroundColor.withAlphaComponent(0.01))))

    }

}

private struct CustomButtonStyle: ButtonStyle {

    let bgColor: Color

    func makeBody(configuration: Self.Configuration) -> some View {

        let fillColor = configuration.isPressed ? Color.accentColor : bgColor

        configuration.label
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(fillColor))

    }
}
