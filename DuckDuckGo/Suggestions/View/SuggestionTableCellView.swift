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

    static let identifier = NSUserInterfaceItemIdentifier("SuggestionTableCellView")

    private enum Constants {
        static let textColor: NSColor = .suggestionText
        static let suffixColor: NSColor = .addressBarSuffix
        static let burnerSuffixColor: NSColor = .burnerAccent
        static let iconColor: NSColor = .suggestionIcon
        static let selectedTintColor: NSColor = .selectedSuggestionTint

        static let switchToTabExtraSpace: CGFloat = 12 + 6 + 9 + 12
        static let switchToTabSuffixPadding: CGFloat = 8

        static let trailingSpace: CGFloat = 8
    }

    @IBOutlet var iconImageView: NSImageView!
    @IBOutlet var removeButton: NSButton!
    @IBOutlet var suffixTextField: NSTextField!
    @IBOutlet var suffixTrailingConstraint: NSLayoutConstraint!
    @IBOutlet var switchToTabBox: ColorView!
    @IBOutlet var switchToTabLabel: NSTextField!
    @IBOutlet var switchToTabArrowView: NSImageView!
    @IBOutlet var switchToTabBoxLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var switchToTabBoxTrailingConstraint: NSLayoutConstraint!

    var suggestion: Suggestion?

    static let switchToTabAttributedString: NSAttributedString = {
        let text = UserText.switchToTab
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .kern: 0.06,
        ]

        return NSAttributedString(string: text, attributes: attributes)
    }()
    private static let switchToTabTextWidth: CGFloat = switchToTabAttributedString.size().width
    private static let switchToTabBoxWidth: CGFloat = switchToTabTextWidth + Constants.switchToTabExtraSpace

    override func awakeFromNib() {
        suffixTextField.textColor = Constants.suffixColor
        removeButton.toolTip = UserText.removeSuggestionTooltip
        switchToTabLabel.attributedStringValue = Self.switchToTabAttributedString
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

    func display(_ suggestionViewModel: SuggestionViewModel, isBurner: Bool) {
        self.isBurner = isBurner
        self.suggestion = suggestionViewModel.suggestion

        attributedString = suggestionViewModel.tableCellViewAttributedString
        iconImageView.image = suggestionViewModel.icon
        suffixTextField.stringValue = suggestionViewModel.suffix
        setRemoveButtonHidden(true)
        if case .openTab = suggestionViewModel.suggestion {
            switchToTabBox.isHidden = false
        } else {
            switchToTabBox.isHidden = true
        }

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
            textField?.textColor = Constants.selectedTintColor
            suffixTextField.textColor = Constants.selectedTintColor
            switchToTabLabel.textColor = Constants.selectedTintColor
            switchToTabArrowView.contentTintColor = Constants.selectedTintColor
            switchToTabBox.backgroundColor = .white.withAlphaComponent(0.09)
        } else {
            textField?.attributedStringValue = attributedString
            textField?.textColor = Constants.textColor
            switchToTabLabel.textColor = Constants.textColor
            switchToTabArrowView.contentTintColor = Constants.textColor
            switchToTabBox.backgroundColor = .buttonMouseOver
            if isBurner {
                suffixTextField.textColor = Constants.burnerSuffixColor
            } else {
                suffixTextField.textColor = Constants.suffixColor
            }
        }
    }

    private func updateImageViews() {
        iconImageView.contentTintColor = isSelected ? Constants.selectedTintColor : Constants.iconColor
        removeButton.contentTintColor = isSelected ? Constants.selectedTintColor : Constants.iconColor
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

    override func layout() {
        if switchToTabBox.isHidden {
            switchToTabBoxLeadingConstraint.isActive = false
            switchToTabBoxTrailingConstraint.isActive = false
            suffixTrailingConstraint.constant = Constants.trailingSpace
        } else {
            var textWidth = attributedString?.boundingRect(with: bounds.size).width ?? 0
            if textWidth < bounds.width {
                textWidth += suffixTextField.attributedStringValue.boundingRect(with: bounds.size).width
            }
            if textField!.frame.minX
                + textWidth
                + Constants.switchToTabSuffixPadding
                + Self.switchToTabBoxWidth
                + Constants.trailingSpace > bounds.width {

                // when cropping title+suffix to fit the Switch to Tab box
                // tie the box to the right boundary
                switchToTabBoxLeadingConstraint.isActive = false
                switchToTabBoxTrailingConstraint.isActive = true
                // crop title+suffix to fit the Switch to Tab box
                suffixTrailingConstraint.constant = Self.switchToTabBoxWidth + Constants.trailingSpace + Constants.switchToTabSuffixPadding
            } else {
                switchToTabBoxTrailingConstraint.isActive = false
                // we can fit everything: align Switch to Tab box left edge after the suffix
                switchToTabBoxLeadingConstraint.constant = textField!.frame.minX + textWidth + Constants.switchToTabSuffixPadding
                switchToTabBoxLeadingConstraint.isActive = true
                suffixTrailingConstraint.constant = Constants.trailingSpace
            }
        }

        super.layout()
    }

}
