//
//  PasswordManagementViewController.swift
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
import Combine
import SwiftUI
import BrowserServicesKit

final class PasswordManagementViewController: NSViewController {

    static func create() -> Self {
        let storyboard = NSStoryboard(name: "PasswordManager", bundle: nil)
        // swiftlint:disable force_cast
        let controller = storyboard.instantiateController(withIdentifier: "PasswordManagement") as! Self
        controller.loadView()
        // swiftlint:enable force_cast
        return controller
    }

    @IBOutlet var listContainer: NSView!

    @Published var isDirty = false

    var model = AccountListModel(accounts: []) {
        print("Item selected \($0)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let view = NSHostingView(rootView: AccountListView().environmentObject(model))
        view.frame = listContainer.frame
        listContainer.addSubview(view)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        model.accounts = (try? SecureVaultFactory.default.makeVault().accounts()) ?? []
    }

    @IBAction func deleteAction(sender: Any) {
        model.accounts = [SecureVaultModels.WebsiteAccount](model.accounts.dropFirst())
    }

}

struct WrappedAccount: Identifiable {

    let id: Int64
    let name: String

}

final class AccountListModel: ObservableObject {

    @Published var accounts: [SecureVaultModels.WebsiteAccount]
    @Published var selected: SecureVaultModels.WebsiteAccount?

    var itemSelected: (SecureVaultModels.WebsiteAccount) -> Void

    init(accounts: [SecureVaultModels.WebsiteAccount], itemSelected: @escaping (Any) -> Void) {
        self.accounts = accounts
        self.itemSelected = itemSelected
    }

    func selectAccount(_ account: SecureVaultModels.WebsiteAccount) {
        selected = account
        itemSelected(account)
    }

}

struct AccountListView: View {

    @EnvironmentObject var model: AccountListModel

    var body: some View {
        List(model.accounts, id: \.id) { account in

            AccountView(account: account, selected: model.selected?.id == account.id) {
                model.selectAccount(account)
            }

        }
        .listStyle(SidebarListStyle())
    }

}

struct AccountView: View {

    let account: SecureVaultModels.WebsiteAccount
    let selected: Bool
    let action: () -> Void

    var body: some View {

        let favicon = LocalFaviconService.shared.getCachedFavicon(for: account.domain, mustBeFromUserScript: false) ?? NSImage(named: "Web")
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

struct CustomButtonStyle: ButtonStyle {

    let bgColor: Color

    func makeBody(configuration: Self.Configuration) -> some View {

        let fillColor = configuration.isPressed ? Color.accentColor : bgColor

        configuration.label
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(fillColor))

    }
}
