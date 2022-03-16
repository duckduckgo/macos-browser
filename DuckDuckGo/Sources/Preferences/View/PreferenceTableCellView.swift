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

    private enum Constants {
        // The padding constants are used when rendering cells that have a divider at the top, such as the About row in Preferences.
        static let rowTopPadding: CGFloat = 10
        static let rowBottomPadding: CGFloat = 20
    }

    static let identifier = NSUserInterfaceItemIdentifier("PreferenceTableCellView")

    @IBOutlet var preferenceImageView: NSImageView!
    @IBOutlet var preferenceTitleLabel: NSTextField!

    @IBOutlet var dividerView: NSBox!
    @IBOutlet var dividerViewTopConstraint: NSLayoutConstraint!
    @IBOutlet var dividerViewBottomConstraint: NSLayoutConstraint!

    var isSelected: Bool = false

    func update(with section: PreferenceSection) {
        dividerView.isHidden = true
        preferenceImageView.image = section.preferenceIcon
        preferenceTitleLabel.stringValue = section.displayName
    }

    func update(with image: NSImage, title: String, addDividerPadding: Bool = false) {
        dividerView.isHidden = false
        preferenceImageView.image = image
        preferenceTitleLabel.stringValue = title
        
        if addDividerPadding {
            dividerViewTopConstraint.constant += Constants.rowTopPadding
            dividerViewBottomConstraint.constant += Constants.rowBottomPadding
        }
    }

    private func resetSelectionState() {
        isSelected = false
    }

}
