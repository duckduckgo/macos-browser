//
//  DefaultBrowserItem.swift
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

final class DefaultBrowserTableCellView: NSTableCellView {

    static let reuseIdentifier = NSUserInterfaceItemIdentifier("DefaultBrowserTableCellView")
    private static let nibName = "DefaultBrowserTableCellView"

    static func nib() -> NSNib {
        return NSNib(nibNamed: nibName, bundle: Bundle.main)!
    }

    @IBOutlet var statusImageView: NSImageView!
    @IBOutlet var statusLabel: NSTextField!
    @IBOutlet var requestDefaultBrowserButton: NSButton!

    var isDefaultBrowser = false {
        didSet {
            requestDefaultBrowserButton.isHidden = isDefaultBrowser

            if isDefaultBrowser {
                statusImageView.image = NSImage(named: "SolidCheckmark")
                statusLabel.stringValue = UserText.isDefaultBrowser
            } else {
                statusImageView.image = NSImage(named: "Warning")
                statusLabel.stringValue = UserText.isNotDefaultBrowser
            }
        }
    }

    @IBAction func requestSetDefaultBrowser(_ sender: NSButton) {
        DefaultBrowserPreferences.becomeDefault()
    }

}
