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
    @IBOutlet var itemContainer: NSView!
    @IBOutlet var searchField: NSTextField!

    @Published var domain: String?
    @Published var isDirty = false

    var listModel: PasswordManagementItemListModel?
    var itemModel: PasswordManagementItemModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        createListView()
        createItemView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        fetchAccounts { [weak self] accounts in
            self?.listModel?.accounts = accounts
            self?.searchField.stringValue = self?.domain ?? ""
            self?.updateFilter()
            self?.listModel?.selectFirst()
        }
    }

    private func createItemView() {
        let itemModel = PasswordManagementItemModel(onEditChanged: { [weak self] isEditing in
            print("Editing \(isEditing)")
            self?.isDirty = isEditing
        }, onSave: {
            print("Item saved \($0)")
        }, onDeleteRequested: {
            print("Request delete \($0)")
        })
        self.itemModel = itemModel

        let view = NSHostingView(rootView: PasswordManagementItemView().environmentObject(itemModel))
        view.frame = itemContainer.bounds
        print(itemContainer.bounds)
        itemContainer.addSubview(view)
        itemContainer.wantsLayer = true
    }

    private func createListView() {
        let listModel = PasswordManagementItemListModel(accounts: []) { [weak self] in
            guard let id = $0.id else { return }
            self?.itemModel?.credentials = try? SecureVaultFactory.default.makeVault().websiteCredentialsFor(accountId: id)
        }
        self.listModel = listModel

        let view = NSHostingView(rootView: PasswordManagementItemListView().environmentObject(listModel))
        view.frame = listContainer.bounds
        listContainer.addSubview(view)
    }

    private func updateFilter() {
        listModel?.filterUsing(text: searchField.stringValue.trimmingWhitespaces())
    }

    private func fetchAccounts(completion: @escaping ([SecureVaultModels.WebsiteAccount]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let accounts = (try? SecureVaultFactory.default.makeVault().accounts()) ?? []
            DispatchQueue.main.async {
                completion(accounts)
            }
        }
    }
    
}

extension PasswordManagementViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ obj: Notification) {
        updateFilter()
    }

}
