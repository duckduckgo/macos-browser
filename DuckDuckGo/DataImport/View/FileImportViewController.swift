//
//  FileImportViewController.swift
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

protocol FileImportViewControllerDelegate: AnyObject {

    func fileImportViewController(_ viewController: FileImportViewController, didSelectCSVFileWithURL: URL?)
    func totalValidLogins(in fileURL: URL) -> Int?

    func fileImportViewController(_ viewController: FileImportViewController, didSelectBookmarksFileWithURL: URL?)
    func totalValidBookmarks(in fileURL: URL) -> Int?
}

final class FileImportViewController: NSViewController {

    enum Constants {
        static let storyboardName = "DataImport"
        static let identifier = "FileImportViewController"
        static let wideStackViewSpacing: CGFloat = 20
        static let narrowStackViewSpacing: CGFloat = 12
    }

    static func create(importSource: DataImport.Source) -> FileImportViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        let controller: FileImportViewController = storyboard.instantiateController(identifier: Constants.identifier)
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
    @IBOutlet var onePassword7InfoView: NSView!
    @IBOutlet var onePassword8InfoView: NSView!

    @IBOutlet var safariSettingsTextField: NSTextField!

    var importSource: DataImport.Source = .csv {
        didSet {
            if oldValue != importSource {
                currentImportState = .awaitingFileSelection
            }

            renderCurrentState()
        }
    }
    weak var delegate: FileImportViewControllerDelegate?

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
        setUpSafariImportInstructions()
        renderCurrentState()
    }

    private func setUpSafariImportInstructions() {
        let safariSettingsTitle: String = {
            if #available(macOS 13.0, *) {
                return UserText.safariSettings
            } else {
                return UserText.safariPreferences
            }
        }()

        safariSettingsTextField.stringValue = "Safari → \(safariSettingsTitle)"
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
            onePassword7InfoView.isHidden = true
            onePassword8InfoView.isHidden = true
            selectFileButton.title = UserText.importLoginsSelectSafariCSVFile
        case .onePassword7:
            descriptionLabel.isHidden = true
            safariInfoView.isHidden = true
            lastPassInfoView.isHidden = true
            onePassword7InfoView.isHidden = false
            onePassword8InfoView.isHidden = true
            selectFileButton.title = UserText.importLoginsSelect1PasswordCSVFile
        case .onePassword8:
            descriptionLabel.isHidden = true
            safariInfoView.isHidden = true
            lastPassInfoView.isHidden = true
            onePassword7InfoView.isHidden = true
            onePassword8InfoView.isHidden = false
            selectFileButton.title = UserText.importLoginsSelect1PasswordCSVFile
        case .lastPass:
            descriptionLabel.isHidden = true
            safariInfoView.isHidden = true
            lastPassInfoView.isHidden = false
            onePassword7InfoView.isHidden = true
            onePassword8InfoView.isHidden = true
            selectFileButton.title = UserText.importLoginsSelectLastPassCSVFile

        case .brave, .chrome, .edge, .firefox:
            assertionFailure("CSV Import not supported for \(importSource)")
            fallthrough
        case .csv:
            descriptionLabel.isHidden = false
            safariInfoView.isHidden = true
            lastPassInfoView.isHidden = true
            onePassword7InfoView.isHidden = true
            onePassword8InfoView.isHidden = true
            selectFileButton.title = UserText.importLoginsSelectCSVFile
        case .bookmarksHTML:
            descriptionLabel.isHidden = true
            safariInfoView.isHidden = true
            lastPassInfoView.isHidden = true
            onePassword7InfoView.isHidden = true
            onePassword8InfoView.isHidden = true
            selectFileButton.title = UserText.importBookmarksSelectHTMLFile
        }
    }

    private func render(state: ImportState) {
        descriptionLabel.stringValue = UserText.csvImportDescription

        switch state {
        case .awaitingFileSelection:
            selectedFileContainer.isHidden = true
            renderAwaitingFileSelectionState()
        case .selectedValidFile(let fileURL):
            // In case the import source has changed, the file selection state's info view needs to be refreshed.
            renderAwaitingFileSelectionState()

            selectedFileContainer.isHidden = false
            selectedFileLabel.stringValue = fileURL.path
            if importSource == .bookmarksHTML {
                let totalBookmarksToImport = self.delegate?.totalValidBookmarks(in: fileURL) ?? 0
                selectFileButton.title = UserText.importBookmarksSelectAnotherFile
                totalValidLoginsLabel.stringValue = UserText.importingFile(validBookmarks: totalBookmarksToImport)
            } else {
                let totalLoginsToImport = self.delegate?.totalValidLogins(in: fileURL) ?? 0
                selectFileButton.title = UserText.importLoginsSelectAnotherFile
                totalValidLoginsLabel.stringValue = UserText.importingFile(validLogins: totalLoginsToImport)
            }
        case .selectedInvalidFile:
            selectedFileLabel.isHidden = false
            if importSource == .bookmarksHTML {
                selectedFileLabel.stringValue = UserText.importBookmarksFailedToReadHTMLFile
                selectFileButton.title = UserText.importBookmarksSelectHTMLFile
            } else {
                selectedFileLabel.stringValue = UserText.importLoginsFailedToReadCSVFile
                selectFileButton.title = UserText.importLoginsSelectCSVFile
            }
        }
    }

    @IBAction func selectFileButtonClicked(_ sender: Any) {
        let fileExtension: String = {
            switch importSource {
            case .bookmarksHTML:
                return "html"
            default:
                return "csv"
            }
        }()
        let panel = NSOpenPanel.filePanel(allowedExtension: fileExtension)
        let result = panel.runModal()

        if result == .OK {
            if let selectedURL = panel.url {
                currentImportState = .selectedValidFile(fileURL: selectedURL)
                switch importSource {
                case .bookmarksHTML:
                    delegate?.fileImportViewController(self, didSelectBookmarksFileWithURL: selectedURL)
                case .csv, .onePassword8, .onePassword7, .lastPass, .safari:
                    delegate?.fileImportViewController(self, didSelectCSVFileWithURL: selectedURL)
                case .brave, .chrome, .edge, .firefox:
                    break
                }
            } else {
                currentImportState = .selectedInvalidFile
                delegate?.fileImportViewController(self, didSelectCSVFileWithURL: nil)
            }
        }

        renderCurrentState()
    }

}
