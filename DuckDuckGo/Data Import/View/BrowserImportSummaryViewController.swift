//
//  BrowserImportSummaryViewController.swift
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

final class BrowserImportSummaryViewController: NSViewController {

    enum Constants {
        static let storyboardName = "DataImport"
        static let identifier = "BrowserImportSummaryViewController"
    }

    static func create(importSummary: DataImport.Summary) -> BrowserImportSummaryViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)

        return storyboard.instantiateController(identifier: Constants.identifier) { (coder) -> BrowserImportSummaryViewController? in
            return BrowserImportSummaryViewController(coder: coder, summary: importSummary)
        }
    }

    @IBOutlet var summaryRowsStackView: NSStackView!

    @IBOutlet var bookmarkSummaryRow: NSView!
    @IBOutlet var bookmarkSummaryLabel: NSTextField!

    @IBOutlet var bookmarkDuplicatesRow: NSView!
    @IBOutlet var bookmarkDuplicatesLabel: NSTextField!

    @IBOutlet var bookmarkFailureRow: NSView!
    @IBOutlet var bookmarkFailureLabel: NSTextField!

    @IBOutlet var passwordSummaryRow: NSView!
    @IBOutlet var passwordSummaryLabel: NSTextField!

    private let summary: DataImport.Summary

    init?(coder: NSCoder, summary: DataImport.Summary) {
        self.summary = summary
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUserInterface()
    }

    private func configureUserInterface() {
        summaryRowsStackView.arrangedSubviews.forEach { arrangedSubview in
            arrangedSubview.isHidden = true
        }

        if let result = summary.bookmarksResult {
            bookmarkSummaryRow.isHidden = false
            bookmarkSummaryLabel.stringValue = UserText.successfulBookmarkImports(result.successful)

            if result.duplicates > 0 {
                bookmarkDuplicatesRow.isHidden = false
                bookmarkDuplicatesLabel.stringValue = UserText.duplicateBookmarkImports(result.duplicates)
            } else {
                bookmarkDuplicatesRow.isHidden = true
            }

            if result.failed > 0 {
                bookmarkFailureRow.isHidden = false
                bookmarkFailureLabel.stringValue = UserText.failedBookmarkImports(result.failed)
            } else {
                bookmarkFailureRow.isHidden = true
            }
        }
        if case .completed(let result) = summary.loginsResult {
            passwordSummaryRow.isHidden = false
            passwordSummaryLabel.stringValue = UserText
                .loginImportSuccessfulBrowserImports(totalSuccessfulImports: result.successfulImports.count)
        }
    }

}
