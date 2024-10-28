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
import os.log
import Suggestions

final class SuggestionTableCellView: NSTableCellView {

    static let identifier = "SuggestionTableCellView"

    static let textColor: NSColor = .suggestionText
    static let suffixColor: NSColor = .addressBarSuffix
    static let burnerSuffixColor: NSColor = .burnerAccent
    static let iconColor: NSColor = .suggestionIcon
    static let selectedTintColor: NSColor = .selectedSuggestionTint

    @IBOutlet weak var iconImageView: NSImageView!
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var suffixTextField: NSTextField!
    @IBOutlet weak var suffixTrailingConstraint: NSLayoutConstraint!

    var suggestion: Suggestion?

    override func awakeFromNib() {
        suffixTextField.textColor = Self.suffixColor
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        updateDeleteImageViewVisibility()
    }

    var isSelected: Bool = false {
        didSet {
            updateImageViews()
            updateTextField()
            updateDeleteImageViewVisibility()
        }
    }

    var isBurner: Bool = false

    func display(_ suggestionViewModel: SuggestionViewModel) {
        self.suggestion = suggestionViewModel.suggestion
        attributedString = suggestionViewModel.tableCellViewAttributedString
        iconImageView.image = suggestionViewModel.icon
        suffixTextField.stringValue = suggestionViewModel.suffix
        setRemoveButtonHidden(true)

        updateTextField()
    }

    private var attributedString: NSAttributedString?

    private func updateTextField() {
        guard let attributedString = attributedString else {
            Logger.general.error("SuggestionTableCellView: Attributed strings are nil")
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

    private func updateImageViews() {
        iconImageView.contentTintColor = isSelected ? Self.selectedTintColor : Self.iconColor
        removeButton.contentTintColor = isSelected ? Self.selectedTintColor : Self.iconColor
    }

    func updateDeleteImageViewVisibility() {
        guard let window = window else { return }
        let mouseLocation = NSEvent.mouseLocation
        let windowFrameInScreen = window.frame

        // If the suggestion is based on history, if the mouse is inside the window's frame and
        // the suggestion is selected, show the delete button
        if let suggestion, suggestion.isHistoryEntry, windowFrameInScreen.contains(mouseLocation) {
            setRemoveButtonHidden(!isSelected)
        } else {
            setRemoveButtonHidden(true)
        }
    }

    private func setRemoveButtonHidden(_ hidden: Bool) {
        removeButton.isHidden = hidden
        suffixTrailingConstraint.priority = hidden ? .required : .defaultLow
    }

}
