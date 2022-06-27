//
//  BookmarksBarCollectionViewItem.swift
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

import Cocoa

protocol BookmarksBarCollectionViewItemDelegate: AnyObject {

    func bookmarksBarCollectionViewItemClicked(_ bookmarksBarCollectionViewItem: BookmarksBarCollectionViewItem)
    func bookmarksBarCollectionViewItemShowContextMenu(_ bookmarksBarCollectionViewItem: BookmarksBarCollectionViewItem)

}

final class BookmarksBarCollectionViewItem: NSCollectionViewItem {

    @IBOutlet var stackView: NSStackView!
    @IBOutlet private var faviconView: NSImageView!
    @IBOutlet private var titleLabel: NSTextField!
    @IBOutlet private var disclosureIndicatorImageView: NSImageView!
    @IBOutlet private var mouseOverView: MouseOverView!

    @IBOutlet private var mouseClickView: MouseClickView! {
        didSet {
            mouseClickView.delegate = self
        }
    }
    
    weak var delegate: BookmarksBarCollectionViewItemDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.wantsLayer = true
        self.view.layer?.cornerRadius = 4.0
        self.view.layer?.masksToBounds = true
    }
    
    func updateItem(labelText: String, isFolder: Bool) {
        self.title = labelText
        self.titleLabel.stringValue = labelText
        self.disclosureIndicatorImageView.isHidden = !isFolder
        
        if isFolder {
            faviconView.image = NSImage(named: "Folder-16")
        } else {
            faviconView.image = NSImage(named: "Bookmark")
        }
    }
    
}

extension BookmarksBarCollectionViewItem: MouseClickViewDelegate {
    
    func mouseClickView(_ mouseClickView: MouseClickView, mouseUpEvent: NSEvent) {
        delegate?.bookmarksBarCollectionViewItemClicked(self)
    }
    
    func mouseClickView(_ mouseClickView: MouseClickView, rightMouseDownEvent: NSEvent) {
        delegate?.bookmarksBarCollectionViewItemShowContextMenu(self)
    }

}
