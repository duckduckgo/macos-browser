//
//  PreferencesListViewController.swift
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
import Combine

final class PreferencesListViewController: NSViewController {

    enum Constants {
        static let storyboardName = "Preferences"
        static let identifier = "PreferencesListViewController"
    }

    static func create() -> PreferencesListViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    @IBOutlet var preferencesTableView: NSTableView!

    @Published var firstVisibleCellIndex: Int = 0

    private var downloadPreferences = DownloadPreferences()

    enum PreferenceSection: Int, CaseIterable {
        case defaultBrowser
        case appearance
        case privacySecurity
        case downloads
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        preferencesTableView.selectionHighlightStyle = .none
        preferencesTableView.gridStyleMask = [.solidHorizontalGridLineMask]

        let defaultBrowserNib = DefaultBrowserTableCellView.nib()
        preferencesTableView.register(defaultBrowserNib, forIdentifier: DefaultBrowserTableCellView.reuseIdentifier)

        let appearanceNib = AppearancePreferencesTableCellView.nib()
        preferencesTableView.register(appearanceNib, forIdentifier: AppearancePreferencesTableCellView.identifier)

        let privacySecurityNib = PrivacySecurityPreferencesTableCellView.nib()
        preferencesTableView.register(privacySecurityNib, forIdentifier: PrivacySecurityPreferencesTableCellView.identifier)

        let downloadsNib = DownloadPreferencesTableCellView.nib()
        preferencesTableView.register(downloadsNib, forIdentifier: DownloadPreferencesTableCellView.identifier)

        preferencesTableView.postsBoundsChangedNotifications = true
        preferencesTableView.enclosingScrollView?.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contentViewDidChangeBounds),
                                               name: NSView.boundsDidChangeNotification,
                                               object: preferencesTableView.enclosingScrollView?.contentView)
    }

    func select(row: Int) {
        preferencesTableView.scrollRowToVisible(row)
    }

    @objc
    func contentViewDidChangeBounds(_ notification: Notification) {
        self.firstVisibleCellIndex = indexForFirstVisibleRow()
    }

    private func indexForFirstVisibleRow() -> Int {
        let visibleRect = preferencesTableView.visibleRect
        let rows = preferencesTableView.rows(in: visibleRect)
        return rows.location
    }

}

extension PreferencesListViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return PreferenceSection.allCases.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let section = PreferencesListViewController.PreferenceSection(rawValue: row) else { return nil }

        switch section {
        case .defaultBrowser:
            let cell: DefaultBrowserTableCellView? = createCell(withIdentifier: DefaultBrowserTableCellView.reuseIdentifier,
                                                                tableView: tableView)
            cell?.isDefaultBrowser = DefaultBrowserPreferences.isDefault
            return cell
        case .appearance:
            let cell: AppearancePreferencesTableCellView? = createCell(withIdentifier: AppearancePreferencesTableCellView.identifier,
                                                                       tableView: tableView)
            cell?.update(with: AppearancePreferences().currentThemeName)
            return cell
        case .privacySecurity:
            let cell: PrivacySecurityPreferencesTableCellView? = createCell(withIdentifier: PrivacySecurityPreferencesTableCellView.identifier,
                                                                            tableView: tableView)
            cell?.delegate = self
            cell?.update(loginDetectionEnabled: PrivacySecurityPreferences().loginDetectionEnabled)
            return cell
        case .downloads:
            let cell: DownloadPreferencesTableCellView? = createCell(withIdentifier: DownloadPreferencesTableCellView.identifier,
                                                                     tableView: tableView)
            cell?.update(downloadLocation: downloadPreferences.selectedDownloadLocation,
                         alwaysRequestDownloadLocation: downloadPreferences.alwaysRequestDownloadLocation)
            cell?.delegate = self
            return cell
        }
    }

    func selectionShouldChange(in tableView: NSTableView) -> Bool {
        return false
    }

    private func createCell<CellType>(withIdentifier identifier: NSUserInterfaceItemIdentifier, tableView: NSTableView) -> CellType? {
        if let view = tableView.makeView(withIdentifier: identifier, owner: self) as? CellType {
            return view
        } else {
            assertionFailure("\(#file): Failed to cast table cell view to corresponding type")
            return nil
        }
    }

}

extension PreferencesListViewController: DownloadPreferencesTableCellViewDelegate {

    func downloadPreferencesTableCellViewRequestedDownloadLocationPicker(_ cell: DownloadPreferencesTableCellView) {
        let downloadPreferences = DownloadPreferences()

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true

        let result = panel.runModal()
        if result == .OK, let selectedURL = panel.url {
            downloadPreferences.select(downloadLocation: selectedURL)
            preferencesTableView.reloadData()
        }
    }

    func downloadPreferencesTableCellView(_ cell: DownloadPreferencesTableCellView,
                                          setAlwaysRequestDownloadLocation alwaysRequest: Bool) {
        downloadPreferences.alwaysRequestDownloadLocation = alwaysRequest
    }

}

extension PreferencesListViewController: PrivacySecurityPreferencesTableCellViewDelegate {

    func privacySecurityPreferencesTableCellViewRequestedFireproofManagementModal(_ cell: PrivacySecurityPreferencesTableCellView) {
        let viewController = FireproofDomainsViewController.create()
        beginSheet(viewController)
    }

    func privacySecurityPreferencesTableCellView(_ cell: PrivacySecurityPreferencesTableCellView, setLoginDetectionEnabled enabled: Bool) {
        var preferences = PrivacySecurityPreferences()
        preferences.loginDetectionEnabled = enabled
    }

}
