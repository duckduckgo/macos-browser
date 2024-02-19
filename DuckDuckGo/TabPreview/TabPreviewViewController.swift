//
//  TabPreviewViewController.swift
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

final class TabPreviewViewController: NSViewController {

    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var urlTextField: NSTextField!
    @IBOutlet weak var snapshotImageView: NSImageView!
    @IBOutlet weak var snapshotImageViewHeightConstraint: NSLayoutConstraint!

}

extension TabPreviewViewController {

    enum TextFieldMaskGradientSize: CGFloat {
        case width = 6
        case trailingSpace = 12
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        titleTextField.maximumNumberOfLines = 3
        titleTextField.cell?.truncatesLastVisibleLine = true
    }

    func display(tabViewModel: TabViewModel, isSelected: Bool) {
        titleTextField.stringValue = tabViewModel.title
        titleTextField.lineBreakMode = isSelected ? .byWordWrapping : .byTruncatingTail

        switch tabViewModel.tab.content {
        case .url(let url, credential: _, source: _):
            urlTextField.stringValue = url.toString(decodePunycode: true,
                                                    dropScheme: true,
                                                    needsWWW: false,
                                                    dropTrailingSlash: true)
        case .bookmarks, .dataBrokerProtection, .newtab, .onboarding, .settings:
            urlTextField.stringValue = "DuckDuckGo Browser"
        default:
            urlTextField.stringValue = ""
        }

        if !isSelected, !tabViewModel.isShowingErrorPage, let snapshot = tabViewModel.tab.tabSnapshot {
            snapshotImageView.image = snapshot
            snapshotImageViewHeightConstraint.constant = getHeight(for: tabViewModel.tab.tabSnapshot)
        } else {
            snapshotImageView.image = nil
            snapshotImageViewHeightConstraint.constant = 0
        }
    }

    private func getHeight(for image: NSImage?) -> CGFloat {
        guard let image else { return 0 }

        let aspectRatio = image.size.width / image.size.height
        let width = TabPreviewWindowController.width
        let height = width / aspectRatio
        return height
    }

}
