//
//  SuggestionWeatherIATableCellView.swift
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

final class SuggestionWeatherIATableCellView: NSTableCellView {

    static let identifier = "SuggestionWeatherIATableCellView"

    static let textColor: NSColor = .suggestionText
    static let suffixColor: NSColor = .addressBarSuffix
    static let burnerSuffixColor: NSColor = .burnerAccent
    static let iconColor: NSColor = .suggestionIcon
    static let selectedTintColor: NSColor = .selectedSuggestionTint

    @IBOutlet weak var iconImageView: NSImageView!
    @IBOutlet weak var suffixTextField: NSTextField!
    @IBOutlet weak var secondaryTextField: NSTextField!

    override func awakeFromNib() {
        suffixTextField.textColor = Self.suffixColor
    }

    var isSelected: Bool = false {
        didSet {
            updateTextField()
        }
    }

    var isBurner: Bool = false

    func display(_ suggestionViewModel: SuggestionViewModel) {
        attributedString = suggestionViewModel.tableCellViewAttributedString
        iconImageView.image = suggestionViewModel.icon
        suffixTextField.stringValue = suggestionViewModel.suffix
        secondaryTextField.stringValue = suggestionViewModel.secondaryString

        updateTextField()
    }

    private var attributedString: NSAttributedString?

    private func updateTextField() {
        guard let attributedString = attributedString else {
            os_log("SuggestionTableCellView: Attributed strings are nil", type: .error)
            return
        }
        if isSelected {
            if let attributedString = attributedString.mutableCopy() as? NSMutableAttributedString {
                attributedString.removeAttribute(.foregroundColor, range: NSRange(location: 0, length: attributedString.length))
                textField?.attributedStringValue = attributedString
            } else {
                textField?.attributedStringValue = attributedString
            }
            textField?.textColor = Self.selectedTintColor
            suffixTextField.textColor = Self.selectedTintColor
            secondaryTextField.textColor = Self.selectedTintColor
        } else {
            textField?.attributedStringValue = attributedString
            textField?.textColor = Self.textColor
            if isBurner {
                suffixTextField.textColor = Self.burnerSuffixColor
            } else {
                suffixTextField.textColor = Self.suffixColor
            }
            secondaryTextField.textColor = NSColor.secondaryLabelColor
        }
    }

}
