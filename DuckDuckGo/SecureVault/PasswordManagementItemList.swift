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

//// Using generic "item list" term as eventually this will be more than just accounts.
///
/// Could maybe even abstract a bunch of this code to be more generic re-usable styled list for use elsewhere.
final class PasswordManagementItemListModel: ObservableObject {

    var accounts: [SecureVaultModels.WebsiteAccount]

    @Published private(set) var displayedAccounts: [SecureVaultModels.WebsiteAccount]
    @Published private(set) var selected: SecureVaultModels.WebsiteAccount?

    var itemSelected: (SecureVaultModels.WebsiteAccount) -> Void

    init(accounts: [SecureVaultModels.WebsiteAccount], itemSelected: @escaping (Any) -> Void) {
        self.accounts = accounts
        self.displayedAccounts = accounts
        self.itemSelected = itemSelected
    }

    func selectAccount(_ account: SecureVaultModels.WebsiteAccount) {
        selected = account
        itemSelected(account)
    }

    func filterUsing(text: String) {
        displayedAccounts = accounts.filter { $0.domain.contains(text) || $0.username.contains(text) }
    }

}

struct PasswordManagementItemListView: View {

    @EnvironmentObject var model: PasswordManagementItemListModel

    var body: some View {
        List(model.displayedAccounts, id: \.id) { account in

            ItemView(account: account, selected: model.selected?.id == account.id) {
                model.selectAccount(account)
            }

        }
        .listStyle(SidebarListStyle())
    }

}

private struct ItemView: View {

    let account: SecureVaultModels.WebsiteAccount
    let selected: Bool
    let action: () -> Void

    var body: some View {

        let favicon = LocalFaviconService.shared.getCachedFavicon(for: account.domain, mustBeFromUserScript: false) ?? NSImage(named: "WebLarge")
        let selectedTextColor = Color(NSColor.selectedControlTextColor)

        Button(action: action, label: {
            HStack(spacing: 4) {
                Image(nsImage: favicon!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.domain).bold()
                        .foregroundColor(selected ? selectedTextColor : nil)
                    Text(account.username)
                        .foregroundColor(selected ? selectedTextColor : nil)
                }
            }
        })
        .buttonStyle(selected ?
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
