//
//  TabBarViewItem.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import os.log

class TabBarViewItem: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "TabBarViewItem")

    @IBOutlet weak var faviconImageView: NSImageView!
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var closeButton: NSButton!
    @IBOutlet weak var rightSeparatorView: ColorView!
    @IBOutlet weak var bottomCornersView: ColorView!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.cornerRadius = 7
        view.layer?.masksToBounds = false
        setViews()
    }

    override var isSelected: Bool {
        didSet {
            if isSelected {
                isDragged = false
            }
            setViews()
        }
    }

    override var draggingImageComponents: [NSDraggingImageComponent] {
        isDragged = true
        return super.draggingImageComponents
    }

    var isDragged = false {
        didSet {
            setViews()
        }
    }

    func display(tabViewModel: TabViewModel) {
        //todo
    }

    private func setViews() {
        let backgroundColor = isSelected || isDragged ? NSColor(named: "InterfaceBackgroundColor") : NSColor.clear

        view.layer?.backgroundColor = backgroundColor?.cgColor
        bottomCornersView.backgroundColor = backgroundColor

        rightSeparatorView.isHidden = isSelected || isDragged
    }

}
