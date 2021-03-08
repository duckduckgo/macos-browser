//
//  WebExtensionCollectionViewItem.swift
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

class WebExtensionCollectionViewItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "WebExtensionCollectionViewItem")

    @IBOutlet weak var iconImageView: NSImageView!
    @IBOutlet weak var nameTextField: NSTextField!
    @IBOutlet weak var descriptionTextField: NSTextField!
    @IBOutlet weak var installButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
    }

    override var isSelected: Bool {
        didSet {
            installButton.isHidden = isSelected
        }
    }

    func set(webExtension: WebExtension) {
        nameTextField.stringValue = webExtension.manifest.name
        iconImageView.image = webExtension.icon
        descriptionTextField.stringValue = webExtension.manifest.description
    }
    
}
