//
//  CSVImportViewController.swift
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

protocol CSVImportViewControllerDelegate: AnyObject {

    func csvImportViewController(_ viewController: CSVImportViewController, didSelectCSVFileWithURL: URL?)

}

final class CSVImportViewController: NSViewController {

    enum Constants {
        static let storyboardName = "DataImport"
        static let identifier = "CSVImportViewController"
        static let wideStackViewSpacing: CGFloat = 20
        static let narrowStackViewSpacing: CGFloat = 12
    }

    static func create(importSource: DataImport.Source) -> CSVImportViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        let controller: CSVImportViewController = storyboard.instantiateController(identifier: Constants.identifier)
        controller.importSource = importSource
        return controller
    }

    @IBOutlet var stackView: NSStackView!

    @IBOutlet var descriptionLabel: NSTextField!
    @IBOutlet var selectFileButton: NSButton!

    @IBOutlet var selectedFileContainer: NSView!
    @IBOutlet var selectedFileLabel: NSTextField!
    @IBOutlet var totalValidLoginsLabel: NSTextField!

    @IBOutlet var safariInfoView: NSView!
    @IBOutlet var lastPassInfoView: NSView!
    @IBOutlet var onePasswordInfoView: NSView!

    var importSource: DataImport.Source = .csv {
        didSet {
            renderCurrentState()
        }
    }
    weak var delegate: CSVImportViewControllerDelegate?

    // MARK: - View State

    private enum ImportState {
        case awaitingFileSelection
        case selectedValidFile(fileURL: URL)
        case selectedInvalidFile
    }

    private var currentImportState: ImportState = .awaitingFileSelection

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        renderCurrentState()
    }

    private func renderCurrentState() {
        guard isViewLoaded else { return }
        render(state: currentImportState)
    }

    private func renderAwaitingFileSelectionState() {
        switch importSource {
        case .safari:
            descriptionLabel.isHidden = true
            safariInfoView.isHidden = false
            lastPassInfoView.isHidden = true
            onePasswordInfoView.isHidden = true
            selectFileButton.title = UserText.importLoginsSelectSafariCSVFile
        case .onePassword:
            descriptionLabel.isHidden = true
            safariInfoView.isHidden = true
            lastPassInfoView.isHidden = true
            onePasswordInfoView.isHidden = false
            selectFileButton.title = UserText.importLoginsSelect1PasswordCSVFile
        case .lastPass:
            descriptionLabel.isHidden = true
            safariInfoView.isHidden = true
            lastPassInfoView.isHidden = false
            onePasswordInfoView.isHidden = true
            selectFileButton.title = UserText.importLoginsSelectLastPassCSVFile

        case .brave, .chrome, .edge, .firefox:
            assertionFailure("CSV Import not supported for \(importSource)")
            fallthrough
        case .csv:
            descriptionLabel.isHidden = false
            safariInfoView.isHidden = true
            lastPassInfoView.isHidden = true
            onePasswordInfoView.isHidden = true
            selectFileButton.title = UserText.importLoginsSelectCSVFile
        }
    }

    private func render(state: ImportState) {
        descriptionLabel.stringValue = UserText.csvImportDescription

        switch state {
        case .awaitingFileSelection:
            selectedFileContainer.isHidden = true
            renderAwaitingFileSelectionState()
        case .selectedValidFile(let fileURL):
            let totalLoginsToImport = CSVImporter.totalValidLogins(in: fileURL)
            selectedFileContainer.isHidden = false
            selectedFileLabel.stringValue = fileURL.path
            selectFileButton.title = UserText.importLoginsSelectAnotherFile
            totalValidLoginsLabel.stringValue = UserText.importingFile(validLogins: totalLoginsToImport)
        case .selectedInvalidFile:
            selectedFileLabel.stringValue = UserText.importLoginsFailedToReadCSVFile
            selectedFileLabel.isHidden = false
            selectFileButton.title = UserText.importLoginsSelectCSVFile
        }
    }

    @IBAction func selectFileButtonClicked(_ sender: Any) {
        let panel = NSOpenPanel.filePanel(allowedExtension: "csv")
        let result = panel.runModal()

        if result == .OK {
            if let selectedURL = panel.url {
                currentImportState = .selectedValidFile(fileURL: selectedURL)
                delegate?.csvImportViewController(self, didSelectCSVFileWithURL: selectedURL)
            } else {
                currentImportState = .selectedInvalidFile
                delegate?.csvImportViewController(self, didSelectCSVFileWithURL: nil)
            }
        }

        renderCurrentState()
    }

}
