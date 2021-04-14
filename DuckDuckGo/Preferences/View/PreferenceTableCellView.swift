//
//  PreferenceTableCellView.swift
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

import Foundation

final class PreferenceTableCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("PreferenceTableCellView")

    @IBOutlet var preferenceImageView: NSImageView!
    @IBOutlet var preferenceTitleLabel: NSTextField!
    @IBOutlet var dividerView: NSBox!

    var isSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    func update(with preference: Preference) {
        dividerView.isHidden = true
        preferenceImageView.image = preference.preferenceIcon
        preferenceTitleLabel.stringValue = preference.displayName
    }

    func update(with image: NSImage, title: String) {
        dividerView.isHidden = false
        preferenceImageView.image = image
        preferenceTitleLabel.stringValue = title
    }

    private func resetSelectionState() {
        isSelected = false
        updateAppearance()
    }

    private func updateAppearance() {

    }

}
