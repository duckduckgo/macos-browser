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

final class DataImportViewController: NSViewController {

    enum Constants {
        static let storyboardName = "DataImport"
        static let identifier = "DataImportViewController"
    }

    static func create() -> DataImportViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)
        return storyboard.instantiateController(identifier: Constants.identifier)
    }

    var importer: CSVLoginImporter?

    @IBOutlet var importButton: NSButton!

    @IBAction func cancelButtonClicked(_ sender: Any) {
        dismiss()
    }

    @IBAction func importButtonClicked(_ sender: Any) {
        guard let importer = importer else {
            assertionFailure("\(#file): No data importer found")
            return
        }

        let data = importer.readLoginEntries()
        print(data)
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let csvImportViewController = segue.destinationController as? CSVImportViewController {
            csvImportViewController.delegate = self
        }
    }

}

extension DataImportViewController: CSVImportViewControllerDelegate {

    func csvImportViewController(_ viewController: CSVImportViewController, didSelectCSVFileWithURL url: URL?) {
        if let url = url {
            self.importer = CSVLoginImporter(fileURL: url)
            self.importButton.isEnabled = true
        } else {
            self.importButton.isEnabled = false
        }
    }

}
