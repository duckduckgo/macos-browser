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

final class DataImportViewController: NSViewController {

    enum Constants {
        static let storyboardName = "DataImport"
        static let identifier = "DataImportViewController"
    }

    enum InteractionState {
        case unableToImport
        case ableToImport
        case failedToImport
        case completedImport
    }

    private struct ViewState {
        var selectedImportSource: DataImport.Source
        var interactionState: InteractionState
    }

    static func create() -> DataImportViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    private var importer: CSVImporter?
    private var viewState: ViewState = ViewState(selectedImportSource: .csv, interactionState: .unableToImport) {
        didSet {
            renderCurrentViewState()
        }
    }

    private weak var currentChildViewController: NSViewController?

    @IBOutlet var containerView: NSView!
    @IBOutlet var importSourcePopUpButton: NSPopUpButton!
    @IBOutlet var importButton: NSButton!

    @IBAction func cancelButtonClicked(_ sender: Any) {
        dismiss()
    }

    @IBAction func importButtonClicked(_ sender: Any) {
        switch viewState.interactionState {
        case .ableToImport: importLogins()
        case .completedImport: dismiss()
        default:
            assertionFailure("\(#file): Import button should be disabled when unable to import")
        }
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // This will change later to select the user's default browser.
        importSourcePopUpButton.displayImportSources(withSelectedSource: .csv)
        renderCurrentViewState()
    }

//    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
//        currentChildViewController = segue.destinationController as? NSViewController
//
//        if let csvImportViewController = segue.destinationController as? CSVImportViewController {
//            csvImportViewController.delegate = self
//        }
//    }

    private func renderCurrentViewState() {
        updateActionButton(with: viewState.interactionState)

        if let viewController = newChildViewController(for: viewState.selectedImportSource, interactionState: viewState.interactionState) {
            embed(viewController: viewController)
        }
    }

    private func updateActionButton(with interactionState: InteractionState) {
        switch interactionState {
        case .unableToImport:
            self.importButton.title = "Import"
            self.importButton.isEnabled = false
        case .ableToImport:
            self.importButton.title = "Import"
            self.importButton.isEnabled = true
        case .completedImport:
            self.importButton.title = "Done"
            self.importButton.isEnabled = true
        case .failedToImport:
            self.importButton.title = "Done"
            self.importButton.isEnabled = true
        }
    }

    private func newChildViewController(for importSource: DataImport.Source, interactionState: InteractionState) -> NSViewController? {
        switch importSource {
        case .csv:
            if interactionState == .completedImport {
                if currentChildViewController is CSVImportSummaryViewController { return nil }
                return CSVImportSummaryViewController.create()
            } else {
                if currentChildViewController is CSVImportViewController { return nil }

                let viewController = CSVImportViewController.create()
                viewController.delegate = self
                return viewController
            }
        }

        return nil
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

    // MARK: - Actions

    private func importLogins() {
        guard let importer = importer else {
            assertionFailure("\(#file): No data importer found")
            return
        }

        let importableTypes = importer.importableTypes()
        importer.importData(types: importableTypes) { result in
            switch result {
            case .success:
                self.viewState.interactionState = .completedImport
            case .failure:
                self.viewState.interactionState = .failedToImport
            }
        }
    }

}

extension DataImportViewController: CSVImportViewControllerDelegate {

    func csvImportViewController(_ viewController: CSVImportViewController, didSelectCSVFileWithURL url: URL?) {
        guard let url = url else {
            self.viewState.interactionState = .unableToImport
            return
        }

        do {
            let secureVault = try SecureVaultFactory.default.makeVault()
            let secureVaultImporter = SecureVaultLoginImporter(secureVault: secureVault)
            self.importer = CSVImporter(fileURL: url, loginImporter: secureVaultImporter)
            self.viewState.interactionState = .ableToImport
        } catch {
            self.viewState.interactionState = .unableToImport
        }
    }

}

extension NSPopUpButton {

    func displayImportSources(withSelectedSource selectedSource: DataImport.Source) {
        removeAllItems()

        var selectedSourceIndex: Int?

        for (index, source) in DataImport.Source.allCases.enumerated() {
            addItem(withTitle: source.importSourceName)

            if source == selectedSource {
                selectedSourceIndex = index
            }
        }

        selectItem(at: selectedSourceIndex ?? 0)
    }

}
