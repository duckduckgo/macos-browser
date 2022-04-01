//
//  CSVImportSummaryViewController.swift
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

final class CSVImportSummaryViewController: NSViewController {

    enum Constants {
        static let storyboardName = "DataImport"
        static let identifier = "CSVImportSummaryViewController"
    }

    static func create(summary: DataImport.Summary?) -> CSVImportSummaryViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)

        return storyboard.instantiateController(identifier: Constants.identifier) { (coder) -> CSVImportSummaryViewController? in
            return CSVImportSummaryViewController(coder: coder, summary: summary)
        }
    }

    @IBOutlet var importCompleteLabel: NSTextField!

    @IBOutlet var successfulImportsLabel: NSTextField!

    private let summary: DataImport.Summary?

    init?(coder: NSCoder, summary: DataImport.Summary?) {
        self.summary = summary
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if case .completed(let result) = summary?.loginsResult {
            successfulImportsLabel.stringValue = UserText.loginImportSuccessfulCSVImports(totalSuccessfulImports: result.successfulImports.count)
        } else {
            successfulImportsLabel.isHidden = true
        }
    }

}
