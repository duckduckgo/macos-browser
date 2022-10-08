//
//  RequestFilePermissionViewController.swift
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

protocol RequestFilePermissionViewControllerDelegate: AnyObject {

    func requestFilePermissionViewControllerDidReceivePermission(_ viewController: RequestFilePermissionViewController)

}

final class RequestFilePermissionViewController: NSViewController {

    enum Constants {
        static let storyboardName = "DataImport"
        static let identifier = "RequestFilePermissionViewController"
    }

    static func create(importSource: DataImport.Source, permissionsRequired: [DataImport.DataType]) -> RequestFilePermissionViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)

        return storyboard.instantiateController(identifier: Constants.identifier) { (coder) -> RequestFilePermissionViewController? in
            return RequestFilePermissionViewController(coder: coder, importSource: importSource, permissionsRequired: permissionsRequired)
        }
    }

    @IBOutlet var descriptionLabel: NSTextField!
    @IBOutlet var requestPermissionButton: NSButton!

    weak var delegate: RequestFilePermissionViewControllerDelegate?

    private let importSource: DataImport.Source
    private let permissionsRequired: [DataImport.DataType]

    init?(coder: NSCoder, importSource: DataImport.Source, permissionsRequired: [DataImport.DataType]) {
        self.importSource = importSource
        self.permissionsRequired = permissionsRequired

        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        descriptionLabel.stringValue = UserText.bookmarkImportSafariPermissionDescription
        requestPermissionButton.title = UserText.bookmarkImportSafariRequestPermissionButtonTitle
    }

    @IBAction private func presentBookmarksOpenPanel(_ sender: AnyObject) {
        if SafariDataImporter.requestSafariDataDirectoryPermission() != nil, SafariDataImporter.canReadBookmarksFile() {
            delegate?.requestFilePermissionViewControllerDidReceivePermission(self)
        }
    }

}
