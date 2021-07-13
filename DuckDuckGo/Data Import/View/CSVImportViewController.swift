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

import Foundation

protocol CSVImportViewControllerDelegate: AnyObject {

    func csvImportViewController(_ viewController: CSVImportViewController, didSelectCSVFileWithURL: URL?)

}

final class CSVImportViewController: NSViewController {

    enum Constants {
        static let storyboardName = "DataImport"
        static let identifier = "CSVImportViewController"
    }

    static func create() -> CSVImportViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    @IBOutlet var selectedFileLabel: NSTextField!
    @IBOutlet var selectFileButton: NSButton!

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
        render(state: currentImportState)
    }

    private func render(state: ImportState) {
        switch state {
        case .awaitingFileSelection:
            selectedFileLabel.isHidden = true
            selectFileButton.isHidden = false
        case .selectedValidFile(let fileURL):
            selectedFileLabel.stringValue = "Importing File: \(fileURL.path)"
            selectedFileLabel.isHidden = false
            selectFileButton.title = "Select Different File"
            selectFileButton.isHidden = false
        case .selectedInvalidFile:
            selectedFileLabel.stringValue = "Invalid File"
            selectedFileLabel.isHidden = false
            selectFileButton.isHidden = true
        }
    }

    @IBAction func selectFileButtonClicked(_ sender: Any) {
        let panel = NSOpenPanel.filePanel(allowedExtension: "csv")
        let result = panel.runModal()

        if result == .OK, let selectedURL = panel.url {
            currentImportState = .selectedValidFile(fileURL: selectedURL)
            delegate?.csvImportViewController(self, didSelectCSVFileWithURL: selectedURL)
        } else {
            currentImportState = .selectedInvalidFile
            delegate?.csvImportViewController(self, didSelectCSVFileWithURL: nil)
        }

        renderCurrentState()
    }
}
