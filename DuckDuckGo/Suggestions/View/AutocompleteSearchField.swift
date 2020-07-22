//
//  AutocompleteSearchField.swift
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
import Combine
import os.log

protocol AutocompleteSearchFieldDelegate: AnyObject {

    func autocompleteSearchField(_ autocompleteSearchField: AutocompleteSearchField, didConfirmStringValue: String)

}

class AutocompleteSearchField: NSSearchField {

    weak var searchFieldDelegate: AutocompleteSearchFieldDelegate?

    private let suggestionsViewModel = SuggestionsViewModel(suggestions: Suggestions())
    private var selectedSuggestionViewModelCancellable: AnyCancellable?

    private var originalStringValue: String?

    override func awakeFromNib() {
        super.awakeFromNib()

        super.delegate = self
        initSuggestionsWindow()
        bindSelectedSuggestionViewModel()
    }

    override func becomeFirstResponder() -> Bool {
        let isFirstResponder = super.becomeFirstResponder()
        if isFirstResponder {
            perform(#selector(selectText(_:)), with: self, afterDelay: 0)
        }

        return isFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        return super.resignFirstResponder()
    }

    func viewDidLayout() {
        layoutSuggestionWindow()
    }

    private func confirmStringValue() {
        hideSuggestionsWindow()
        searchFieldDelegate?.autocompleteSearchField(self, didConfirmStringValue: stringValue)
    }

    private func bindSelectedSuggestionViewModel() {
        selectedSuggestionViewModelCancellable = suggestionsViewModel.$selectedSuggestionViewModel.sinkAsync { _ in
            self.displaySelectedSuggestionViewModel()
        }
    }

    private func displaySelectedSuggestionViewModel() {
        guard let selectedSuggestionViewModel = suggestionsViewModel.selectedSuggestionViewModel else {
            if let originalStringValue = originalStringValue {
                stringValue = originalStringValue
            } else {
                stringValue = ""
            }
            return
        }

        switch selectedSuggestionViewModel.suggestion {
        case .phrase(phrase: let phrase):
            stringValue = phrase
        case .website(url: let url, title: _):
            stringValue = url.absoluteString
        case .unknown(value: let value):
            stringValue = value
        }
    }

    // MARK: - Suggestions window

    private var suggestionsWindowController: NSWindowController?

    private func initSuggestionsWindow() {
        let storyboard = NSStoryboard(name: "Suggestions", bundle: nil)
        let creator: (NSCoder) -> SuggestionsViewController? = { coder in
            let suggestionsViewController = SuggestionsViewController(coder: coder, suggestionsViewModel: self.suggestionsViewModel)
            suggestionsViewController?.delegate = self
            return suggestionsViewController
        }

        let windowController = storyboard.instantiateController(withIdentifier: "SuggestionsWindowController") as? NSWindowController
        let suggestionsViewController = storyboard.instantiateController(identifier: "SuggestionsViewController", creator: creator)

        windowController?.contentViewController = suggestionsViewController
        self.suggestionsWindowController = windowController
    }

    private func showSuggestionsWindow() {
        guard let window = window, let suggestionsWindow = suggestionsWindowController?.window else {
            os_log("AutocompleteSearchField: Window not available", log: OSLog.Category.general, type: .error)
            return
        }

        if !suggestionsWindow.isVisible {
            window.addChildWindow(suggestionsWindow, ordered: .above)
        }

        layoutSuggestionWindow()
    }

    private func hideSuggestionsWindow() {
        guard let window = window, let suggestionsWindow = suggestionsWindowController?.window else {
            os_log("AutocompleteSearchField: Window not available", log: OSLog.Category.general, type: .error)
            return
        }

        if !suggestionsWindow.isVisible { return }

        window.removeChildWindow(suggestionsWindow)
        suggestionsWindow.parent?.removeChildWindow(suggestionsWindow)
        suggestionsWindow.orderOut(nil)
    }

    private func layoutSuggestionWindow() {
        guard let window = window, let suggestionsWindow = suggestionsWindowController?.window else {
            os_log("AutocompleteSearchField: Window not available", log: OSLog.Category.general, type: .error)
            return
        }

        let padding = CGFloat(3)
        suggestionsWindow.setFrame(NSRect(x: 0, y: 0, width: frame.width + 2 * padding, height: 0), display: true)

        var point = bounds.origin
        point.y += frame.height
        point.y += padding
        point.x -= padding

        let converted = convert(point, to: nil)
        let screen = window.convertPoint(toScreen: converted)
        suggestionsWindow.setFrameTopLeftPoint(screen)
    }
}

extension AutocompleteSearchField: NSSearchFieldDelegate {

    func controlTextDidEndEditing(_ obj: Notification) {
        let textMovement = obj.userInfo?["NSTextMovement"] as? Int
        if textMovement == NSReturnTextMovement {
            confirmStringValue()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        suggestionsViewModel.suggestions.getSuggestions(for: stringValue)
        originalStringValue = stringValue

        if stringValue.isEmpty {
            hideSuggestionsWindow()
        } else {
            showSuggestionsWindow()
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard suggestionsWindowController?.window?.isVisible == true else {
            return false
        }

        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            suggestionsViewModel.selectNextIfPossible(); return true
        case #selector(NSResponder.moveUp(_:)):
            suggestionsViewModel.selectPreviousIfPossible(); return true
        case #selector(NSResponder.deleteBackward(_:)), #selector(NSResponder.deleteForward(_:)):
            suggestionsViewModel.clearSelection(); return false
        default:
            return false
        }
    }

}

extension AutocompleteSearchField: SuggestionsViewControllerDelegate {

    func suggestionsViewControllerDidConfirmSelection(_ suggestionsViewController: SuggestionsViewController) {
        confirmStringValue()
    }

}
