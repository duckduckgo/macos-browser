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

        ScrollView {
            VStack(alignment: .leading) {
                Spacer(minLength: 10)

                ForEach(model.displayedAccounts, id: \.id) { account in
                    ItemView(account: account, selected: model.selected?.id == account.id) {
                        model.selectAccount(account)
                    }
                    .padding(.horizontal, 10)
                }
            }
        }

    }

}

private struct ItemView: View {

    let account: SecureVaultModels.WebsiteAccount
    let selected: Bool
    let action: () -> Void

    var body: some View {

        let textColor = selected ? Color(NSColor.selectedControlTextColor) : Color(NSColor.controlTextColor)
        let font = Font.custom("SFProText-Regular", size: 13)
        let displayName = ((account.title ?? "").isEmpty == true ? account.domain.dropWWW() : account.title) ?? ""

        Button(action: action, label: {
            HStack(spacing: 0) {

                FaviconView(domain: account.domain)
                    .padding(.leading, 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .foregroundColor(textColor)
                        .font(font)
                    Text(account.username)
                        .foregroundColor(textColor.opacity(0.6))
                        .font(font)
                }
                .padding(.leading, 4)
            }
        })
        .frame(maxHeight: 48)
        .buttonStyle(selected ?
                        CustomButtonStyle(bgColor: Color(NSColor.selectedControlColor)) :
                        // Almost clear, so that whole view is clickable
                        CustomButtonStyle(bgColor: Color(NSColor.windowBackgroundColor.withAlphaComponent(0.001))))

    }

}

private struct CustomButtonStyle: ButtonStyle {

    let bgColor: Color

    func makeBody(configuration: Self.Configuration) -> some View {

        let fillColor = configuration.isPressed ? Color.accentColor : bgColor

        configuration.label
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .truncationMode(.tail)
            .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(fillColor))

    }
}
