//
//  SuggestionTableCellView.swift
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
import Common

final class SuggestionTableCellView: NSTableCellView {

    static let identifier = "SuggestionTableCellView"

    static let textColor = NSColor.suggestionTextColor
    static let suffixColor = NSColor.addressBarSuffixColor
    static let burnerSuffixColor = NSColor.burnerAccentColor
    static let iconColor = NSColor.suggestionIconColor
    static let selectedTintColor = NSColor.selectedSuggestionTintColor

    @IBOutlet weak var iconImageView: NSImageView!
    @IBOutlet weak var suffixTextField: NSTextField!

    override func awakeFromNib() {
        suffixTextField.textColor = Self.suffixColor
    }

    var isSelected: Bool = false {
        didSet {
            updateIconImageView()
            updateTextField()
        }
    }

    var isBurner: Bool = false

    func display(_ suggestionViewModel: SuggestionViewModel) {
        attributedString = suggestionViewModel.tableCellViewAttributedString
        iconImageView.image = suggestionViewModel.icon
        suffixTextField.stringValue = suggestionViewModel.suffix

        updateTextField()
    }

    private var attributedString: NSAttributedString?

    private func updateTextField() {
        guard let attributedString = attributedString else {
            os_log("SuggestionTableCellView: Attributed strings are nil", type: .error)
            return
        }
        if isSelected {
            textField?.attributedStringValue = attributedString
            textField?.textColor = Self.selectedTintColor
            suffixTextField.textColor = Self.selectedTintColor
        } else {
            textField?.attributedStringValue = attributedString
            textField?.textColor = Self.textColor
            if isBurner {
                suffixTextField.textColor = Self.burnerSuffixColor
            } else {
                suffixTextField.textColor = Self.suffixColor
            }
        }
    }

    private func updateIconImageView() {
        iconImageView.contentTintColor = isSelected ? Self.selectedTintColor : Self.iconColor
    }

}
