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
    @IBOutlet var searchField: NSTextField!

    @Published var domain: String?
    @Published var isDirty = false

    var filterText: String = ""

    var model = PasswordManagementItemListModel(accounts: []) {
        print("Item selected \($0)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        createListView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        fetchAccounts { [weak self] accounts in
            self?.model.accounts = accounts
            self?.searchField.stringValue = self?.domain ?? ""
            self?.updateFilter()
        }
    }

    @IBAction func deleteAction(sender: Any) {
        model.accounts = [SecureVaultModels.WebsiteAccount](model.accounts.dropFirst())
    }

    private func createListView() {
        let view = NSHostingView(rootView: PasswordManagementItemListView().environmentObject(model))
        view.frame = listContainer.frame
        listContainer.addSubview(view)
    }

    private func updateFilter() {
        model.filterUsing(text: searchField.stringValue)
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
