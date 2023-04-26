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
    @IBOutlet weak var faviconImageView: NSImageView!

}

extension TabPreviewViewController {

    enum TextFieldMaskGradientSize: CGFloat {
        case width = 6
        case trailingSpace = 12
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupGradients()
    }

    func display(tabViewModel: TabViewModel) {
        titleTextField.stringValue = tabViewModel.title

        // Search queries can match valid URL formats, so prevent creating a URL object from the address bar string if on a search page.
        if !(tabViewModel.tab.content.urlForWebView?.isDuckDuckGoSearch ?? false),
           let url = URL(trimmedAddressBarString: tabViewModel.addressBarString),
           let punycodeDecoded = url.punycodeDecodedString {
            urlTextField.stringValue = punycodeDecoded
        } else {
            urlTextField.stringValue = tabViewModel.addressBarString
        }
        faviconImageView.image = tabViewModel.favicon
    }

    private func setupGradients() {
        titleTextField.wantsLayer = true
        titleTextField.gradient(width: TextFieldMaskGradientSize.width.rawValue,
                                trailingPadding: TextFieldMaskGradientSize.trailingSpace.rawValue)
        urlTextField.wantsLayer = true
        urlTextField.gradient(width: TextFieldMaskGradientSize.width.rawValue,
                              trailingPadding: TextFieldMaskGradientSize.trailingSpace.rawValue)
    }

}
