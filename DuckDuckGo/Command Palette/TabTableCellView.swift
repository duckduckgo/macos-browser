//
//  TabTableCellView.swift
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

import Cocoa

final class TabTableCellView: NSTableCellView {
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var urlTextField: NSTextField!
    @IBOutlet weak var faviconImageView: NSImageView!

    override var objectValue: Any? {
        didSet {
            guard let some = objectValue else { return }
            guard let tabViewModel = some as? TabViewModel else { fatalError("Unexpected object value") }
            display(tabViewModel)
        }
    }

    func display(_ model: TabViewModel) {
        titleTextField.stringValue = model.title
        urlTextField.stringValue = model.addressBarString
        faviconImageView.image = model.favicon
    }

}
