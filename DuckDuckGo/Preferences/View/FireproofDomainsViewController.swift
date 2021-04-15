//
//  FireproofDomainsViewController.swift
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

import AppKit

final class FireproofDomainsViewController: NSViewController {

    enum Constants {
        static let storyboardName = "Preferences"
        static let identifier = "FireproofDomainsViewController"
        static let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "FireproofDomainCell")
    }

    static func create() -> FireproofDomainsViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var removeDomainButton: NSButton!

    private var fireproofDomains = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()
        applyModalWindowStyleIfNeeded()
        reloadData()
    }

    private func updateRemoveButtonState() {
        removeDomainButton.isEnabled = tableView.selectedRow > -1
    }

    fileprivate func reloadData() {
        fireproofDomains = FireproofDomains.shared.fireproofDomains.sorted { (lhs, rhs) -> Bool in
            return lhs < rhs
        }

        tableView.reloadData()
        updateRemoveButtonState()
    }

    @IBAction func doneButtonClicked(_ sender: NSButton) {
        dismiss()
    }

    @IBAction func removeSelectedDomain(_ sender: NSButton) {
        guard tableView.selectedRow > -1 else {
            updateRemoveButtonState()
            return
        }

        let selectedDomain = fireproofDomains[tableView.selectedRow]
        FireproofDomains.shared.remove(domain: selectedDomain)
        reloadData()
    }

    @IBAction func removeAllDomains(_ sender: NSButton) {
        FireproofDomains.shared.clearAll()
        reloadData()
    }

}

extension FireproofDomainsViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return fireproofDomains.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return fireproofDomains[row]
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.makeView(withIdentifier: Constants.cellIdentifier, owner: nil) as? NSTableCellView {
            let domain = fireproofDomains[row]
            cell.textField?.stringValue = domain
            return cell
        }

        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveButtonState()
    }

}
