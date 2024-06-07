//
//  FirePopoverCollectionViewItem.swift
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

protocol FirePopoverCollectionViewItemDelegate: AnyObject {

    func firePopoverCollectionViewItemDidToggle(_ firePopoverCollectionViewItem: FirePopoverCollectionViewItem)

}

final class FirePopoverCollectionViewItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "FirePopoverCollectionViewItem")

    weak var delegate: FirePopoverCollectionViewItemDelegate?

    @IBOutlet weak var domainTextField: NSTextField!
    @IBOutlet weak var checkButton: NSButton!
    @IBOutlet weak var faviconImageView: NSImageView! {
       didSet {
           faviconImageView.applyFaviconStyle()
       }
   }

    func setItem(_ item: FirePopoverViewModel.Item, isFireproofed: Bool) {
        domainTextField.stringValue = item.domain
        faviconImageView.image = item.favicon ?? .web
        checkButton.isHidden = isFireproofed
    }

    @IBAction func checkButtonAction(_ sender: Any) {
        delegate?.firePopoverCollectionViewItemDidToggle(self)
    }

    override func mouseDown(with event: NSEvent) {
        delegate?.firePopoverCollectionViewItemDidToggle(self)
    }

    override var isSelected: Bool {
        didSet {
            checkButton.state = isSelected ? .on : .off
        }
    }

}
