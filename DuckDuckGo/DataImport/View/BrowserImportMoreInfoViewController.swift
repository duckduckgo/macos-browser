//
//  BrowserImportMoreInfoViewController.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

final class BrowserImportMoreInfoViewController: NSViewController {

    enum Constants {
        static let storyboardName = "DataImport"
        static let identifier = "BrowserImportMoreInfoViewController"
    }

    static func create(source: DataImport.Source) -> Self {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)

        return storyboard.instantiateController(identifier: Constants.identifier) { (coder) -> Self? in
            return Self.init(coder: coder, source: source)
        }
    }

    let source: DataImport.Source

    init?(coder: NSCoder, source: DataImport.Source) {
        self.source = source
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @IBOutlet weak var label: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        switch source {
        case .chrome, .edge, .brave:
            label.stringValue = UserText.importFromChromiumMoreInfo

        case .firefox:
            label.stringValue = UserText.importFromFirefoxMoreInfo

        case .safari, .csv, .lastPass, .onePassword, .bookmarksHTML:
            fatalError("Unsupported source for more info")
        }
    }

}
