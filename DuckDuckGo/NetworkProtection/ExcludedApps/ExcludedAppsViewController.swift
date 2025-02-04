//
//  ExcludedAppsViewController.swift
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
import AppInfoRetriever

final class ExcludedAppsViewController: NSViewController {
    typealias Model = ExcludedAppsModel

    enum Constants {
        static let storyboardName = "ExcludedApps"
        static let identifier = "ExcludedAppsViewController"
        static let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "ExcludedAppCell")
    }

    static func create(model: Model = DefaultExcludedAppsModel()) -> ExcludedAppsViewController {
        let storyboard = loadStoryboard()

        return storyboard.instantiateController(identifier: Constants.identifier) { coder in
            ExcludedAppsViewController(model: model, coder: coder)
        }
    }

    static func loadStoryboard() -> NSStoryboard {
        NSStoryboard(name: Constants.storyboardName, bundle: nil)
    }

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var addAppButton: NSButton!
    @IBOutlet var removeAppButton: NSButton!
    @IBOutlet var doneButton: NSButton!
    @IBOutlet var titleLabel: NSTextField!

    private let faviconManagement: FaviconManagement = FaviconManager.shared

    private var allApps = [AppInfo]()
    private var filteredApps: [AppInfo]?

    private var visibleApps: [AppInfo] {
        return filteredApps ?? allApps
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
        addAppButton.title = UserText.vpnExcludedAppsAddApp
        removeAppButton.title = UserText.remove
        doneButton.title = UserText.done
        titleLabel.stringValue = UserText.vpnExcludedAppsTitle
    }

    private func updateRemoveButtonState() {
        removeAppButton.isEnabled = tableView.selectedRow > -1
    }

    fileprivate func reloadData() {
        allApps = model.excludedApps.sorted { (lhs, rhs) -> Bool in
            return lhs < rhs
        }.map { bundleID in
            model.getAppInfo(bundleID: bundleID)
        }

        tableView.reloadData()
        updateRemoveButtonState()
    }

    @IBAction func doneButtonClicked(_ sender: NSButton) {
        dismiss()
    }

    @IBAction func addApp(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK,
              let appURL = panel.url else {
            return
        }

        add(appURL: appURL)
    }

    private func add(appURL: URL) {
        Task {
            guard let appInfo = model.add(appURL: appURL) else {
                return
            }
            reloadData()

            if let newRowIndex = allApps.firstIndex(of: appInfo) {
                tableView.scrollRowToVisible(newRowIndex)
            }
        }
    }

    @IBAction func removeSelected(_ sender: NSButton) {
        guard tableView.selectedRow > -1 else {
            updateRemoveButtonState()
            return
        }

        let appInfo = visibleApps[tableView.selectedRow]
        model.remove(bundleID: appInfo.bundleID)
        reloadData()
    }
}

extension ExcludedAppsViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return visibleApps.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return visibleApps[row]
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: Constants.cellIdentifier, owner: nil) as? NSTableCellView else {

            return nil
        }

        let appInfo = visibleApps[row]

        cell.textField?.stringValue = appInfo.name
        cell.imageView?.image = appInfo.icon
        cell.imageView?.applyFaviconStyle()

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveButtonState()
    }
}

extension ExcludedAppsViewController: NSTextFieldDelegate {

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSSearchField else { return }

        if field.stringValue.isEmpty {
            filteredApps = nil
        } else {
            filteredApps = allApps.filter {
                $0.name.contains(field.stringValue) || $0.bundleID.contains(field.stringValue)
            }
        }

        reloadData()
    }
}
