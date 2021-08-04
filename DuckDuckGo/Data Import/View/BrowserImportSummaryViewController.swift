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

import Foundation

final class BrowserImportSummaryViewController: NSViewController {

    enum Constants {
        static let storyboardName = "DataImport"
        static let identifier = "BrowserImportSummaryViewController"
    }

    static func create(importSummaries: [DataImport.Summary]) -> BrowserImportSummaryViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)

        return storyboard.instantiateController(identifier: Constants.identifier) { (coder) -> BrowserImportSummaryViewController? in
            return BrowserImportSummaryViewController(coder: coder, summaries: importSummaries)
        }
    }

    @IBOutlet var summaryRowsStackView: NSStackView!

    @IBOutlet var passwordSummaryRow: NSView!
    @IBOutlet var passwordSummaryLabel: NSTextField!

    private let summaries: [DataImport.Summary]

    init?(coder: NSCoder, summaries: [DataImport.Summary]) {
        self.summaries = summaries
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

        for summary in summaries {
            switch summary {
            case .logins(let successfulImports, let duplicateImports, let failedImports):
                passwordSummaryRow.isHidden = false
                passwordSummaryLabel.stringValue = "Passwords: \(successfulImports.count)"
            }
        }
    }

}
