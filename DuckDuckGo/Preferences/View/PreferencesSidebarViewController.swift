//
//  PreferencesSidebarViewController.swift
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

protocol PreferencesSidebarViewControllerDelegate: class {

    func selected(detailViewType: PreferencesDetailViewType)

}

final class PreferencesSidebarViewController: NSViewController {

    @IBOutlet var preferencesTableView: NSTableView!

    weak var delegate: PreferencesSidebarViewControllerDelegate?

    /// PreferencesSidebarViewController monitors `tableViewSelectionDidChange` in order to tell the detail view which section to scroll to.
    /// However, the detail view also communicates its row changes back to this view controller, so this property tracks if that change is currently being handled.
    /// Otherwise, when the detail view selects a new index, the table view selection will change here and be forwarded _back_ to the detail view controller, causing visual issues.
    private var handlingDetailViewScrollEvent = false

    var preferenceSections = PreferenceSections() {
        didSet {
            preferencesTableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        preferencesTableView.dataSource = self
        preferencesTableView.delegate = self

        preferencesTableView.target = self
        preferencesTableView.action = #selector(selectedRow)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        preferencesTableView.makeMeFirstResponder()
    }

    func detailViewScrolledTo(rowAtIndex row: Int) {
        handlingDetailViewScrollEvent = true
        let indexSet = IndexSet(integer: row)
        preferencesTableView.selectRowIndexes(indexSet, byExtendingSelection: false)
    }

    @objc private func selectedRow() {
        let selectedRow = preferencesTableView.selectedRow

        if selectedRow < preferenceSections.sections.count {
            delegate?.selected(detailViewType: .preferencesList(selectedRowIndex: selectedRow))
        } else if selectedRow == preferenceSections.sections.count {
            delegate?.selected(detailViewType: .about)
        } else {
            assertionFailure("\(#file): Selected cell with invalid index")
        }
    }

}

extension PreferencesSidebarViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return preferenceSections.sections.count + 1
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: PreferenceTableCellView.identifier, owner: self) as? PreferenceTableCellView else {
            assertionFailure("\(#file): Failed to cast table cell view to corresponding type")
            return nil
        }

        if row < preferenceSections.sections.count {
            let preference = preferenceSections.sections[row]
            cell.update(with: preference)
        } else if row == preferenceSections.sections.count {
            cell.update(with: NSImage(named: "Preferences")!, title: "About")
        } else {
            assertionFailure("\(#file): Tried to update cell with invalid index")
            return nil
        }
        
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return RoundedSelectionRowView()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if handlingDetailViewScrollEvent {
            handlingDetailViewScrollEvent = false
        } else {
            selectedRow()
        }
    }

}
