//
//  ExcludedDomainsViewController.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

final class ExcludedDomainsViewController: NSViewController {
    typealias Model = ExcludedDomainsViewModel

    enum Constants {
        static let storyboardName = "ExcludedDomains"
        static let identifier = "ExcludedDomainsViewController"
        static let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "ExcludedDomainCell")
    }

    static func create(model: Model = DefaultExcludedDomainsViewModel()) -> ExcludedDomainsViewController {
        let storyboard = loadStoryboard()

        return storyboard.instantiateController(identifier: Constants.identifier) { coder in
            ExcludedDomainsViewController(model: model, coder: coder)
        }
    }

    static func loadStoryboard() -> NSStoryboard {
        NSStoryboard(name: Constants.storyboardName, bundle: nil)
    }

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var addDomainButton: NSButton!
    @IBOutlet var removeDomainButton: NSButton!
    @IBOutlet var doneButton: NSButton!
    @IBOutlet var excludedDomainsLabel: NSTextField!

    private let faviconManagement: FaviconManagement = FaviconManager.shared

    private var allDomains = [String]()
    private var filteredDomains: [String]?

    private var visibleDomains: [String] {
        return filteredDomains ?? allDomains
    }

    private let model: Model

    init?(model: Model, coder: NSCoder) {
        self.model = model

        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyModalWindowStyleIfNeeded()
        reloadData()
        setUpStrings()
    }

    private func setUpStrings() {
        addDomainButton.title = UserText.vpnExcludedDomainsAddDomain
        removeDomainButton.title = UserText.remove
        doneButton.title = UserText.done
        excludedDomainsLabel.stringValue = UserText.vpnExcludedDomainsTitle
    }

    private func updateRemoveButtonState() {
        removeDomainButton.isEnabled = tableView.selectedRow > -1
    }

    fileprivate func reloadData() {
        allDomains = model.domains.sorted { (lhs, rhs) -> Bool in
            return lhs < rhs
        }

        tableView.reloadData()
        updateRemoveButtonState()
    }

    @IBAction func doneButtonClicked(_ sender: NSButton) {
        dismiss()
    }

    @IBAction func addDomain(_ sender: NSButton) {
        AddExcludedDomainView(title: UserText.vpnAddExcludedDomainTitle, buttonsState: .compressed, cancelActionTitle: UserText.vpnAddExcludedDomainCancelButtonTitle, cancelAction: { dismiss in

            dismiss()
        }, defaultActionTitle: UserText.vpnAddExcludedDomainActionButtonTitle) { [weak self] domain, dismiss in
            guard let self else { return }

            addDomain(domain)
            dismiss()
        }.show(in: view.window)
    }

    private func addDomain(_ domain: String) {
        Task {
            model.add(domain: domain)
            reloadData()

            if let newRowIndex = allDomains.firstIndex(of: domain) {
                tableView.scrollRowToVisible(newRowIndex)
            }

            await model.askUserToReportIssues(withDomain: domain, in: view.window)
        }
    }

    @IBAction func removeSelectedDomain(_ sender: NSButton) {
        guard tableView.selectedRow > -1 else {
            updateRemoveButtonState()
            return
        }

        let selectedDomain = visibleDomains[tableView.selectedRow]
        model.remove(domain: selectedDomain)
        reloadData()
    }
}

extension ExcludedDomainsViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return visibleDomains.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return visibleDomains[row]
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: Constants.cellIdentifier, owner: nil) as? NSTableCellView else {

            return nil
        }

        let domain = visibleDomains[row]

        cell.textField?.stringValue = domain
        cell.imageView?.image = faviconManagement.getCachedFavicon(forDomainOrAnySubdomain: domain, sizeCategory: .small)?.image
        cell.imageView?.applyFaviconStyle()

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveButtonState()
    }
}

extension ExcludedDomainsViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSSearchField else { return }

        if field.stringValue.isEmpty {
            filteredDomains = nil
        } else {
            filteredDomains = allDomains.filter { $0.contains(field.stringValue) }
        }

        reloadData()
    }

}
