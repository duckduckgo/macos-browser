//
//  DataImportViewController.swift
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
import BrowserServicesKit
import Combine
import os.log

// swiftlint:disable type_body_length
final class DataImportViewController: NSViewController {

    enum Constants {
        static let storyboardName = "DataImport"
        static let identifier = "DataImportViewController"
    }

    enum InteractionState {
        case unableToImport
        case permissionsRequired([DataImport.DataType])
        case ableToImport
        case moreInfoAvailable
        case failedToImport
        case completedImport([DataImport.Summary])
    }

    private struct ViewState {
        var selectedImportSource: DataImport.Source
        var interactionState: InteractionState
        
        static func defaultState() -> ViewState {
            if let firstInstalledBrowser = ThirdPartyBrowser.installedBrowsers.first {
                return ViewState(selectedImportSource: firstInstalledBrowser.importSource,
                                 interactionState: firstInstalledBrowser.importSource == .safari ? .ableToImport : .moreInfoAvailable)
            } else {
                return ViewState(selectedImportSource: .csv, interactionState: .ableToImport)
            }
        }
    }

    static func show(completion: (() -> Void)? = nil) {
        guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController,
              windowController.window?.isKeyWindow == true else {
            return
        }

        let viewController = DataImportViewController.create()
        windowController.mainViewController.beginSheet(viewController) { _ in
            completion?()
        }
    }

    static func create() -> DataImportViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    private func secureVaultImporter() throws -> SecureVaultLoginImporter {
        let secureVault = try SecureVaultFactory.default.makeVault(errorReporter: SecureVaultErrorReporter.shared)
        return SecureVaultLoginImporter(secureVault: secureVault)
    }

    private var viewState: ViewState = .defaultState() {
        didSet {

            renderCurrentViewState()

            let bookmarkImporter = CoreDataBookmarkImporter(bookmarkManager: LocalBookmarkManager.shared)

            do {
                switch viewState.selectedImportSource {
                case .brave:
                    self.dataImporter = try BraveDataImporter(loginImporter: secureVaultImporter(), bookmarkImporter: bookmarkImporter)
                case .chrome:
                    self.dataImporter = try ChromeDataImporter(loginImporter: secureVaultImporter(), bookmarkImporter: bookmarkImporter)
                case .edge:
                    self.dataImporter = try EdgeDataImporter(loginImporter: secureVaultImporter(), bookmarkImporter: bookmarkImporter)
                case .firefox:
                    self.dataImporter = try FirefoxDataImporter(loginImporter: secureVaultImporter(), bookmarkImporter: bookmarkImporter)
                case .safari:
                    self.dataImporter = SafariDataImporter(bookmarkImporter: bookmarkImporter)
                case .csv:
                    if !(self.dataImporter is CSVImporter) {
                        self.dataImporter = nil
                    }
                }
            } catch {
                os_log("dataImporter initialization failed: %{public}s", type: .error, error.localizedDescription)
                self.presentAlert(for: .cannotAccessSecureVault)
            }
        }
    }

    private weak var currentChildViewController: NSViewController?
    private var browserImportViewController: BrowserImportViewController?

    private var dataImporter: DataImporter?
    private var selectedImportSourceCancellable: AnyCancellable?

    @IBOutlet var containerView: NSView!
    @IBOutlet var importSourcePopUpButton: NSPopUpButton!
    @IBOutlet var importButton: NSButton!
    @IBOutlet var cancelButton: NSButton!

    @IBAction func cancelButtonClicked(_ sender: Any) {
        if currentChildViewController is BrowserImportMoreInfoViewController {
            viewState = .init(selectedImportSource: viewState.selectedImportSource, interactionState: .moreInfoAvailable)
            importSourcePopUpButton.isEnabled = true
            cancelButton.title = UserText.cancel
        } else {
            dismiss()
        }
    }

    @IBAction func actionButtonClicked(_ sender: Any) {
        switch viewState.interactionState {
        case .ableToImport, .failedToImport: beginImport()
        case .completedImport: dismiss()
        case .moreInfoAvailable: showMoreInfo()
        default:
            assertionFailure("\(#file): Import button should be disabled when unable to import")
        }
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        importSourcePopUpButton.displayImportSources()
        renderCurrentViewState()

        selectedImportSourceCancellable = importSourcePopUpButton.selectionPublisher.sink { [weak self] _ in
            self?.refreshViewState()
        }
    }

    private func refreshViewState() {
        let item = self.importSourcePopUpButton.itemArray[importSourcePopUpButton.indexOfSelectedItem]
        let validSources = DataImport.Source.allCases.filter(\.canImportData)
        let source = validSources.first(where: { $0.importSourceName == item.title })!

        switch source {
        case .csv:
            self.viewState = ViewState(selectedImportSource: source, interactionState: .unableToImport)

        case .safari:
            let state: InteractionState = SafariDataImporter.canReadBookmarksFile() ? .ableToImport : .permissionsRequired([.bookmarks])
            self.viewState = ViewState(selectedImportSource: source, interactionState: state)

        case .chrome, .firefox, .brave, .edge:
            self.viewState = ViewState(selectedImportSource: source,
                                       interactionState: loginsSelected ? .moreInfoAvailable : .ableToImport)
        }

    }

    var loginsSelected: Bool {
        if let browserViewController = self.currentChildViewController as? BrowserImportViewController {
            return browserViewController.selectedImportOptions.contains(.logins)
        }

        // Assume true as a default in order to show next button when new child view controller is set
        return true
    }

    private func renderCurrentViewState() {
        updateActionButton(with: viewState.interactionState)

        if let viewController = newChildViewController(for: viewState.selectedImportSource, interactionState: viewState.interactionState) {
            embed(viewController: viewController)
        }
    }

    private func updateActionButton(with interactionState: InteractionState) {
        switch interactionState {
        case .unableToImport:
            importSourcePopUpButton.isHidden = false
            importButton.title = UserText.initiateImport
            importButton.isEnabled = false
            cancelButton.isHidden = false
        case .ableToImport:
            importSourcePopUpButton.isHidden = false
            importButton.title = UserText.initiateImport
            importButton.isEnabled = true
            cancelButton.isHidden = false
        case .moreInfoAvailable:
            importSourcePopUpButton.isHidden = false
            importButton.title = UserText.next
            importButton.isEnabled = true
            cancelButton.isHidden = false
        case .permissionsRequired:
            importSourcePopUpButton.isHidden = false
            importButton.title = UserText.initiateImport
            importButton.isEnabled = false
            cancelButton.isHidden = false
        case .completedImport:
            importSourcePopUpButton.isHidden = true
            importButton.title = UserText.doneImporting
            importButton.isEnabled = true
            cancelButton.isHidden = true
        case .failedToImport:
            importSourcePopUpButton.isHidden = false
            importButton.title = UserText.initiateImport
            importButton.isEnabled = true
            cancelButton.isHidden = false
        }
    }

    private func newChildViewController(for importSource: DataImport.Source, interactionState: InteractionState) -> NSViewController? {
        switch importSource {
        case .brave, .chrome, .edge, .firefox, .safari:
            if case let .completedImport(summaryArray) = interactionState {
                return BrowserImportSummaryViewController.create(importSummaries: summaryArray)
            } else if case let .permissionsRequired(types) = interactionState {
                let filePermissionViewController =  RequestFilePermissionViewController.create(importSource: importSource, permissionsRequired: types)
                filePermissionViewController.delegate = self
                return filePermissionViewController
            } else if browserImportViewController?.browser == importSource {
                return browserImportViewController
            } else {
                browserImportViewController = createBrowserImportViewController(for: importSource)
                return browserImportViewController
            }

        case .csv:
            if case let .completedImport(summaryArray) = interactionState {
                if currentChildViewController is CSVImportSummaryViewController { return nil }

                let loginImportSummary: DataImport.Summary? = summaryArray.first {
                    if case .logins = $0 {
                        return true
                    }

                    return false
                }

                return CSVImportSummaryViewController.create(summary: loginImportSummary)
            } else {
                if currentChildViewController is CSVImportViewController { return nil }
                let viewController = CSVImportViewController.create()
                viewController.delegate = self
                return viewController
            }
        }
    }

    private func embed(viewController newChildViewController: NSViewController) {
        if let currentChildViewController = currentChildViewController {
            addChild(newChildViewController)
            transition(from: currentChildViewController, to: newChildViewController, options: [])
        } else {
            addChild(newChildViewController)
        }

        currentChildViewController = newChildViewController
        containerView.addSubview(newChildViewController.view)

        newChildViewController.view.translatesAutoresizingMaskIntoConstraints = false
        newChildViewController.view.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        newChildViewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        newChildViewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        newChildViewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
    }

    private func createBrowserImportViewController(for source: DataImport.Source) -> BrowserImportViewController? {
        // Prevent transitioning to the same view controller.
        if let viewController = currentChildViewController as? BrowserImportViewController, viewController.browser == source { return nil }

        guard let browser = ThirdPartyBrowser.browser(for: viewState.selectedImportSource), let profileList = browser.browserProfiles else {
            assertionFailure("Attempted to create BrowserImportViewController without a valid browser selected")
            return nil
        }

        let browserImportViewController = BrowserImportViewController.create(with: source, profileList: profileList)
        browserImportViewController.delegate = self

        return browserImportViewController
    }

    // MARK: - Actions

    private func showMoreInfo() {
        viewState = .init(selectedImportSource: viewState.selectedImportSource, interactionState: .ableToImport)
        importSourcePopUpButton.isEnabled = false
        embed(viewController: BrowserImportMoreInfoViewController.create(source: viewState.selectedImportSource))
        cancelButton.title = UserText.navigateBack
    }

    private func beginImport() {
        if let browser = ThirdPartyBrowser.browser(for: viewState.selectedImportSource), browser.isRunning {
            let alert = NSAlert.closeRunningBrowserAlert(source: viewState.selectedImportSource)
            let result = alert.runModal()

            if result == NSApplication.ModalResponse.alertFirstButtonReturn {
                browser.forceTerminate()

                // Add a delay before completing the import. Completing the import immediately after a successful `forceTerminate` call does not
                // always leave enough time for the browser's SQLite data to become unlocked.
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                    self.completeImport()
                }
            } else {
                // If the cancel button was selected, abandon the import.
                return
            }
        } else {
            completeImport()
        }

    }

    var selectedProfile: DataImport.BrowserProfile? {
        return browserImportViewController?.selectedProfile
    }

    var selectedImportOptions: [DataImport.DataType] {
        guard let importer = self.dataImporter else {
            assertionFailure("\(#file): No data importer or profile found")
            return []
        }
        return browserImportViewController?.selectedImportOptions ?? importer.importableTypes()
    }

    private func completeImport() {
        guard let importer = self.dataImporter else {
            assertionFailure("\(#file): No data importer or profile found")
            return
        }

        let profile = selectedProfile
        let importTypes = selectedImportOptions

        importer.importData(types: importTypes, from: profile) { result in
            switch result {
            case .success(let summary):
                if summary.isEmpty {
                    self.dismiss()
                } else {
                    self.viewState.interactionState = .completedImport(summary)
                }

                if importTypes.contains(.logins) {
                    self.fireImportLoginsPixelForSelectedImportSource()
                } else if importTypes.contains(.bookmarks) {
                    self.fireImportBookmarksPixelForSelectedImportSource()
                }
            case .failure(let error):
                switch error {
                case .needsLoginPrimaryPassword:
                    self.presentAlert(for: error)
                default:
                    self.viewState.interactionState = .failedToImport
                    self.presentAlert(for: error)
                }
            }
        }
    }

    private func presentAlert(for error: DataImportError) {
        guard let window = view.window else { return }

        switch error {
        case .needsLoginPrimaryPassword:
            let alert = NSAlert.passwordRequiredAlert(source: viewState.selectedImportSource)
            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                // Assume Firefox, as it's the only supported option that uses a password
                let password = (alert.accessoryView as? NSSecureTextField)?.stringValue
                (dataImporter as? FirefoxDataImporter)?.primaryPassword = password

                completeImport()
            }
        default:
            let alert = NSAlert.importFailedAlert(source: viewState.selectedImportSource, errorMessage: error.localizedDescription)
            alert.beginSheetModal(for: window, completionHandler: nil)
        }
    }

    private func fireImportLoginsPixelForSelectedImportSource() {
        switch self.viewState.selectedImportSource {
        case .brave: Pixel.fire(.importedLogins(source: .brave))
        case .chrome: Pixel.fire(.importedLogins(source: .chrome))
        case .csv: Pixel.fire(.importedLogins(source: .csv))
        case .edge: Pixel.fire(.importedLogins(source: .edge))
        case .firefox: Pixel.fire(.importedLogins(source: .firefox))
        case .safari: assertionFailure("Attempted to fire Safari login import pixel") // Safari cannot import logins
        }
    }

    private func fireImportBookmarksPixelForSelectedImportSource() {
        switch self.viewState.selectedImportSource {
        case .brave: Pixel.fire(.importedBookmarks(source: .brave))
        case .chrome: Pixel.fire(.importedBookmarks(source: .chrome))
        case .csv: assertionFailure("Attempted to fire CSV bookmark import pixel")
        case .edge: Pixel.fire(.importedBookmarks(source: .edge))
        case .firefox: Pixel.fire(.importedBookmarks(source: .firefox))
        case .safari: Pixel.fire(.importedBookmarks(source: .safari))
        }
    }

}
// swiftlint:enable type_body_length

extension DataImportViewController: CSVImportViewControllerDelegate {

    func csvImportViewController(_ viewController: CSVImportViewController, didSelectCSVFileWithURL url: URL?) {
        guard let url = url else {
            self.viewState.interactionState = .unableToImport
            return
        }

        do {
            let secureVault = try SecureVaultFactory.default.makeVault(errorReporter: SecureVaultErrorReporter.shared)
            let secureVaultImporter = SecureVaultLoginImporter(secureVault: secureVault)
            self.dataImporter = CSVImporter(fileURL: url, loginImporter: secureVaultImporter)
            self.viewState.interactionState = .ableToImport
        } catch {
            self.viewState.interactionState = .unableToImport
            self.presentAlert(for: .cannotAccessSecureVault)
        }
    }

}

extension DataImportViewController: BrowserImportViewControllerDelegate {

    func browserImportViewController(_ viewController: BrowserImportViewController, didChangeSelectedImportOptions options: [DataImport.DataType]) {
        if options.isEmpty {
            viewState.interactionState = .unableToImport
        } else {
            refreshViewState()
        }
    }

}

extension DataImportViewController: RequestFilePermissionViewControllerDelegate {

    func requestFilePermissionViewControllerDidReceivePermission(_ viewController: RequestFilePermissionViewController) {
        self.viewState.interactionState = .ableToImport
    }

}

extension NSPopUpButton {

    fileprivate func displayImportSources() {
        removeAllItems()

        let validSources = DataImport.Source.allCases.filter(\.canImportData)

        for source in validSources {
            // The CSV row is at the bottom of the picker, and requires a separator above it.
            if source == .csv {
                let separator = NSMenuItem.separator()
                menu?.addItem(separator)
            }

            addItem(withTitle: source.importSourceName)
            lastItem?.image = source.importSourceImage?.resized(to: NSSize(width: 16, height: 16))
        }
    }

}
