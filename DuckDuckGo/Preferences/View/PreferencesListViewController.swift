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
import LocalAuthentication

final class GridClipTableView: NSTableView {

    override func drawGrid(inClipRect clipRect: NSRect) { }

}

final class PreferencesListViewController: NSViewController {

    enum Constants {
        static let storyboardName = "Preferences"
        static let identifier = "PreferencesListViewController"
    }

    static func create() -> PreferencesListViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    @IBOutlet var preferencesTableView: GridClipTableView!

    @Published var firstVisibleCellIndex: Int = 0

    private var downloadPreferences = DownloadPreferences()
    private var isScrollingToNewPreferenceSection = false

    enum PreferenceSection: Int, CaseIterable {
        case defaultBrowser
        case appearance
        case privacySecurity
        case logins
        case downloads
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        preferencesTableView.selectionHighlightStyle = .none

        let defaultBrowserNib = DefaultBrowserTableCellView.nib()
        preferencesTableView.register(defaultBrowserNib, forIdentifier: DefaultBrowserTableCellView.identifier)

        let appearanceNib = AppearancePreferencesTableCellView.nib()
        preferencesTableView.register(appearanceNib, forIdentifier: AppearancePreferencesTableCellView.identifier)

        let privacySecurityNib = PrivacySecurityPreferencesTableCellView.nib()
        preferencesTableView.register(privacySecurityNib, forIdentifier: PrivacySecurityPreferencesTableCellView.identifier)

        let loginsNib = LoginsPreferencesTableCellView.nib()
        preferencesTableView.register(loginsNib, forIdentifier: LoginsPreferencesTableCellView.identifier)
        
        let downloadsNib = DownloadPreferencesTableCellView.nib()
        preferencesTableView.register(downloadsNib, forIdentifier: DownloadPreferencesTableCellView.identifier)

        preferencesTableView.postsBoundsChangedNotifications = true
        preferencesTableView.enclosingScrollView?.contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contentViewDidChangeBounds),
                                               name: NSView.boundsDidChangeNotification,
                                               object: preferencesTableView.enclosingScrollView?.contentView)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadDefaultBrowserRow),
                                               name: NSApplication.willBecomeActiveNotification,
                                               object: nil)

        DistributedNotificationCenter.default().addObserver(self,
                                                            selector: #selector(reloadAppearanceSensitiveRows),
                                                            name: Notification.Name("AppleColorPreferencesChangedNotification"),
                                                            object: nil)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        reloadDefaultBrowserRow()
    }

    func select(row: Int) {
        isScrollingToNewPreferenceSection = true
        preferencesTableView.scrollRowToVisible(row)
    }

    @objc
    func contentViewDidChangeBounds(_ notification: Notification) {
        if isScrollingToNewPreferenceSection {
            isScrollingToNewPreferenceSection = false
        } else {
            self.firstVisibleCellIndex = indexForFirstVisibleRow()
        }
    }

    @objc
    private func reloadDefaultBrowserRow() {
        // In order to detect whether the default browser has changed, this function checks every time the view appears or the app comes back from
        // the background.
        reloadRow(for: .defaultBrowser)
    }

    @objc
    private func reloadAppearanceSensitiveRows() {
        reloadRow(for: .appearance)
    }

    private func indexForFirstVisibleRow() -> Int {
        let visibleRect = preferencesTableView.visibleRect
        let rows = preferencesTableView.rows(in: visibleRect)
        return rows.location
    }

    fileprivate func reloadRow(for preferenceSection: PreferenceSection) {
        let row = preferenceSection.rawValue
        preferencesTableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
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
            let cell: DefaultBrowserTableCellView? = createCell(identifier: DefaultBrowserTableCellView.identifier, tableView: tableView)
            cell?.isDefaultBrowser = DefaultBrowserPreferences.isDefault
            return cell
        case .appearance:
            let cell: AppearancePreferencesTableCellView? = createCell(identifier: AppearancePreferencesTableCellView.identifier,
                                                                       tableView: tableView)
            cell?.update(with: AppearancePreferences().currentThemeName)
            return cell
        case .privacySecurity:
            let cell: PrivacySecurityPreferencesTableCellView? = createCell(identifier: PrivacySecurityPreferencesTableCellView.identifier,
                                                                            tableView: tableView)
            cell?.delegate = self
            let preferences = PrivacySecurityPreferences.shared
            cell?.update(loginDetectionEnabled: preferences.loginDetectionEnabled,
                         gpcEnabled: preferences.gpcEnabled,
                         autoconsentEnabled: preferences.autoconsentEnabled)
            return cell
        case .logins:
            let cell: LoginsPreferencesTableCellView? = createCell(identifier: LoginsPreferencesTableCellView.identifier,
                                                                   tableView: tableView)
            cell?.delegate = self
            let preferences = LoginsPreferences()
            cell?.update(autoLockEnabled: preferences.shouldAutoLockLogins, threshold: preferences.autoLockThreshold)
            return cell
        case .downloads:
            let cell: DownloadPreferencesTableCellView? = createCell(identifier: DownloadPreferencesTableCellView.identifier, tableView: tableView)
            cell?.update(downloadLocation: downloadPreferences.selectedDownloadLocation,
                         alwaysRequestDownloadLocation: downloadPreferences.alwaysRequestDownloadLocation)
            cell?.delegate = self
            return cell
        }
    }

    func selectionShouldChange(in tableView: NSTableView) -> Bool {
        return false
    }

    private func createCell<CellType>(identifier: NSUserInterfaceItemIdentifier, tableView: NSTableView) -> CellType? {
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
        var downloadPreferences = DownloadPreferences()

        let panel = NSOpenPanel.downloadDirectoryPanel()
        let result = panel.runModal()

        if result == .OK, let selectedURL = panel.url {
            downloadPreferences.selectedDownloadLocation = selectedURL
            reloadRow(for: .downloads)
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
        PrivacySecurityPreferences.shared.loginDetectionEnabled = enabled
    }

    func privacySecurityPreferencesTableCellView(_ cell: PrivacySecurityPreferencesTableCellView, setGPCEnabled enabled: Bool) {
        PrivacySecurityPreferences.shared.gpcEnabled = enabled
    }
    
    func privacySecurityPreferencesTableCellView(_ cell: PrivacySecurityPreferencesTableCellView, setAutoconsentEnabled enabled: Bool) {
        PrivacySecurityPreferences.shared.autoconsentEnabled = enabled
    }

}

extension PreferencesListViewController: LoginsPreferencesTableCellViewDelegate {
    
    func loginsPreferencesTableCellView(_ cell: LoginsPreferencesTableCellView,
                                        setShouldAutoLockLogins: Bool,
                                        autoLockThreshold: LoginsPreferences.AutoLockThreshold) {

        DeviceAuthenticator.shared.authenticateUser(reason: .changeLoginsSettings) { authenticated in
            var preferences = LoginsPreferences()

            if authenticated {
                
                // Only fire the auto-lock disabled pixel the setting is disabled and it has changed from its previous value
                if !setShouldAutoLockLogins && setShouldAutoLockLogins != preferences.shouldAutoLockLogins {
                    Pixel.fire(.passwordManagerLockScreenDisabled)
                }
                
                // Only fire the threshold pixel if it has changed, or if the setting is being turned on again
                if (autoLockThreshold != preferences.autoLockThreshold) || (setShouldAutoLockLogins && !preferences.shouldAutoLockLogins) {
                    Pixel.fire(autoLockThreshold.pixelEvent)
                }
                
                preferences.shouldAutoLockLogins = setShouldAutoLockLogins
                preferences.autoLockThreshold = autoLockThreshold
            } else {
                cell.update(autoLockEnabled: preferences.shouldAutoLockLogins, threshold: preferences.autoLockThreshold)
            }
        }

    }
    
}
