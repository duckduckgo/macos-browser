//
//  BrowserImportViewController.swift
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

protocol BrowserImportViewControllerDelegate: AnyObject {

    func browserImportViewController(_ viewController: BrowserImportViewController, didChangeSelectedImportOptions options: [DataImport.DataType])

}

final class BrowserImportViewController: NSViewController {

    enum Constants {
        static let storyboardName = "DataImport"
        static let identifier = "BrowserImportViewController"
    }

    static func create(with browser: DataImport.Source) -> BrowserImportViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)

        return storyboard.instantiateController(identifier: Constants.identifier) { (coder) -> BrowserImportViewController? in
            return BrowserImportViewController(coder: coder, browser: browser)
        }
    }

    @IBOutlet var passwordsCheckbox: NSButton!
    @IBOutlet var passwordDetailLabel: NSTextField!
    @IBOutlet var closeBrowserWarningLabel: NSTextField!
    @IBOutlet var closeBrowserWarningView: ColorView! {
        didSet {
            closeBrowserWarningView.backgroundColor = NSColor.black.withAlphaComponent(0.05)
        }
    }

    weak var delegate: BrowserImportViewControllerDelegate?

    var selectedImportOptions: [DataImport.DataType] {
        var options = [DataImport.DataType]()

        if passwordsCheckbox.state == .on {
            options.append(.logins)
        }

        return options
    }

    let browser: DataImport.Source

    init?(coder: NSCoder, browser: DataImport.Source) {
        self.browser = browser
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.closeBrowserWarningLabel.stringValue = "You must close \(browser.importSourceName) before importing data."

        switch browser {
        case .brave, .chrome, .edge:
            passwordDetailLabel.stringValue = UserText.chromiumPasswordImportDisclaimer
        case .firefox:
            passwordDetailLabel.stringValue = UserText.firefoxPasswordImportDisclaimer
        default:
            passwordDetailLabel.isHidden = true
        }
    }

    @IBAction func selectedImportOptionsChanged(_ sender: NSButton) {
        delegate?.browserImportViewController(self, didChangeSelectedImportOptions: selectedImportOptions)
    }

}
