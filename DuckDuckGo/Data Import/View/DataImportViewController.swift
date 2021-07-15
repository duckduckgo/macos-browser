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

    enum ViewState {
        case unableToImport
        case ableToImport
        case failedToImport
        case completedImport
    }

    static func create() -> DataImportViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    private var importer: CSVImporter?
    private var viewState: ViewState = .unableToImport {
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
        guard let importer = importer else {
            assertionFailure("\(#file): No data importer found")
            return
        }

        let importableTypes = importer.importableTypes()
        importer.importData(types: importableTypes) { result in
            switch result {
            case .success:
                self.viewState = .completedImport
            case .failure:
                self.viewState = .failedToImport
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // This will change later to select the user's default browser.
        importSourcePopUpButton.displayImportSources(withSelectedSource: .csv)
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        currentChildViewController = segue.destinationController as? NSViewController

        if let csvImportViewController = segue.destinationController as? CSVImportViewController {
            csvImportViewController.delegate = self
        }
    }

    private func renderCurrentViewState() {
        switch viewState {
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

}

extension DataImportViewController: CSVImportViewControllerDelegate {

    func csvImportViewController(_ viewController: CSVImportViewController, didSelectCSVFileWithURL url: URL?) {
        guard let url = url else {
            self.viewState = .unableToImport
            return
        }

        do {
            let secureVault = try SecureVaultFactory.default.makeVault()
            let secureVaultImporter = SecureVaultLoginImporter(secureVault: secureVault)
            self.importer = CSVImporter(fileURL: url, loginImporter: secureVaultImporter)
            self.viewState = .ableToImport
        } catch {
            self.viewState = .unableToImport
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
