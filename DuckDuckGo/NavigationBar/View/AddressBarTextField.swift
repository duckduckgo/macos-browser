//
//  AddressBarTextField.swift
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

//swiftlint:disable type_body_length

class AddressBarTextField: NSTextField {

    var tabCollectionViewModel: TabCollectionViewModel! {
        didSet {
            bindSelectedTabViewModel()
        }
    }

    var suggestionsViewModel: SuggestionsViewModel! {
        didSet {
            initSuggestionsWindow()
            bindSuggestionItems()
            bindSelectedSuggestionViewModel()
        }
    }

    private var suggestionItemsCancellable: AnyCancellable?
    private var selectedSuggestionViewModelCancellable: AnyCancellable?
    private var selectedTabViewModelCancelable: AnyCancellable?
    private var searchSuggestionsCancelable: AnyCancellable?
    private var addressBarStringCancelable: AnyCancellable?

    override func awakeFromNib() {
        super.awakeFromNib()

        allowsEditingTextAttributes = true
        super.delegate = self
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        currentEditor()?.selectAll(self)
    }

    func viewDidLayout() {
        layoutSuggestionWindow()
    }

    func clearValue() {
        value = .text("")
    }

    private func bindSuggestionItems() {
        suggestionItemsCancellable = suggestionsViewModel.suggestions.$items.receive(on: DispatchQueue.main).sink { [weak self] _ in
            if self?.suggestionsViewModel.suggestions.items?.count ?? 0 > 0 {
                self?.showSuggestionsWindow()
            }
        }
    }

    private func bindSelectedSuggestionViewModel() {
        selectedSuggestionViewModelCancellable =
            suggestionsViewModel.$selectedSuggestionViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.displaySelectedSuggestionViewModel()
        }
    }

    private func bindSelectedTabViewModel() {
        selectedTabViewModelCancelable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.bindAddressBarString()
        }
    }

    private func bindAddressBarString() {
        addressBarStringCancelable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            clearValue()
            return
        }
        addressBarStringCancelable = selectedTabViewModel.$addressBarString.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateValue()
            self?.makeMeFirstResponderIfNeeded()
        }
    }

    private func updateValue() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }
        let addressBarString = selectedTabViewModel.addressBarString
        value = Value(stringValue: addressBarString, userTyped: false)
    }

    private func makeMeFirstResponderIfNeeded() {
        if stringValue == "" {
            makeMeFirstResponder()
        }
    }

    private func displaySelectedSuggestionViewModel() {
        guard let suggestionsWindow = suggestionsWindowController?.window else {
            os_log("AddressBarTextField: Window not available", log: OSLog.Category.general, type: .error)
            return
        }
        guard suggestionsWindow.isVisible else { return }

        guard let selectedSuggestionViewModel = suggestionsViewModel.selectedSuggestionViewModel else {
            if let originalStringValue = suggestionsViewModel.userStringValue {
                value = Value(stringValue: originalStringValue, userTyped: true)
            } else {
                clearValue()
            }

            return
        }

        value = Value.suggestion(selectedSuggestionViewModel)
        selectToTheEnd(from: cursorPosition)
    }

    private func confirmStringValue() {
        hideSuggestionsWindow()
        setUrl()
    }

    private func setUrl() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }
        guard let url = URL.makeURL(from: stringValueWithoutSuffix) else {
            os_log("%s: Making url from address bar string failed", log: OSLog.Category.general, type: .error, className)
            return
        }
        selectedTabViewModel.tab.url = url
    }

    // MARK: - Value

    enum Value {
        case text(_ text: String)
        case url(urlString: String, url: URL, userTyped: Bool)
        case suggestion(_ suggestionViewModel: SuggestionViewModel)

        init(stringValue: String, userTyped: Bool) {
            if let url = stringValue.url, url.isValid {
                self = .url(urlString: stringValue, url: url, userTyped: userTyped)
            } else {
                self = .text(stringValue)
            }
        }

        var string: String {
            switch self {
            case .text(let text): return text
            case .url(urlString: let urlString, url: _, userTyped: _): return urlString
            case .suggestion(let suggestionViewModel): return suggestionViewModel.string
            }
        }
    }

    @Published private(set) var value: Value = .text("") {
        didSet {
            var stringValue = ""
            switch value {
            case .text(let text):
                stringValue = text
            case .url(urlString: let urlString, url: _, userTyped: _):
                stringValue = urlString
            case .suggestion(let suggestionViewModel):
                stringValue = suggestionViewModel.string
            }
            suffix = Suffix(value: value)

            if let suffix = suffix {
                let attributedString = NSMutableAttributedString(string: value.string, attributes: Self.textAttributes)
                attributedString.append(suffix.attributedString)
                attributedStringValue = attributedString
            } else {
                self.stringValue = stringValue
            }
        }
    }

    // MARK: - Suffixes

    static let textAttributes = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13, weight: .regular),
                                 .foregroundColor: NSColor.textColor]

    enum Suffix {
        init?(value: Value) {
            if case .text("") = value {
                return nil
            }

            switch value {
            case .text: self = Suffix.search
            case .url(urlString: _, url: let url, userTyped: let userTyped):
                if !userTyped { return nil }
                self = Suffix.visit(host: url.host ?? url.absoluteString)
            case .suggestion(let suggestionViewModel):
                switch suggestionViewModel.suggestion {
                case .phrase(phrase: _): self = Suffix.search
                case .website(url: let url): self = Suffix.visit(host: url.host ?? url.absoluteString)
                case .unknown(value: _): self = Suffix.search
                }
            }
        }

        case search
        case visit(host: String)

        static let suffixAttributes = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12, weight: .light),
                                       .foregroundColor: NSColor(named: "AddressBarSuffixColor")!]

        var attributedString: NSAttributedString {
            switch self {
            case .search:
                return NSAttributedString(string: string, attributes: Self.suffixAttributes)
            case .visit(host: _):
                return NSAttributedString(string: string, attributes: Self.suffixAttributes)
            }
        }

        var string: String {
            switch self {
            case .search:
                return " — Search DuckDuckGo"
            case .visit(host: let host):
                return " — Visit \(host)"
            }
        }
    }

    private var suffix: Suffix?
    private var suffixLength: Int {
        suffix?.string.count ?? 0
    }

    private var stringValueWithoutSuffix: String {
        if let suffix = suffix {
            return stringValue.drop(suffix: suffix.string)
        } else {
            return stringValue
        }
    }

    // MARK: - Cursor & Selection

    private var cursorPosition: Int {
        guard let currentEditor = currentEditor() else {
            os_log("AddressBarTextField: Current editor not available", log: OSLog.Category.general, type: .error)
            return 0
        }

        return currentEditor.selectedRange.location
    }

    private func selectToTheEnd(from position: Int) {
        guard let currentEditor = currentEditor() else {
            os_log("AddressBarTextField: Current editor not available", log: OSLog.Category.general, type: .error)
            return
        }

        currentEditor.selectedRange = NSRange(location: position, length: stringValue.count - position - suffixLength)
    }

    private func filterSuffixSelection() {
        guard let currentEditor = currentEditor() else {
            os_log("AddressBarTextField: Current editor not available", log: OSLog.Category.general, type: .error)
            return
        }

        let currentLocation = currentEditor.selectedRange.location
        let currentLength = currentEditor.selectedRange.length
        let currentSelectionEnd = currentLocation + currentLength
        let suffixStart = stringValue.count - suffixLength
        guard suffixStart >= 0 else { return }

        if currentSelectionEnd > suffixStart {
            let newLocation = min(currentLocation, suffixStart)
            let newMaxLength = suffixStart - newLocation
            let newLength = min(newMaxLength, currentSelectionEnd - newLocation)
            let newRange = NSRange(location: newLocation, length: newLength)
            if currentEditor.selectedRange != newRange {
                currentEditor.selectedRange = newRange
            }
        }
    }

    @objc private func textViewDidChangeSelection(_ notification: Notification) {
        guard notification.object as? NSObject == self.currentEditor() else {
            return
        }

        filterSuffixSelection()
    }

    // MARK: - Suggestions window

    enum SuggestionsWindowSizes: CGFloat {
        case padding = 10
    }

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
            os_log("AddressBarTextField: Window not available", log: OSLog.Category.general, type: .error)
            return
        }
        guard !suggestionsWindow.isVisible, window.firstResponder == currentEditor() else { return }

        window.addChildWindow(suggestionsWindow, ordered: .above)
        layoutSuggestionWindow()
    }

    private func hideSuggestionsWindow() {
        guard let window = window, let suggestionsWindow = suggestionsWindowController?.window else {
            os_log("AddressBarTextField: Window not available", log: OSLog.Category.general, type: .error)
            return
        }

        if !suggestionsWindow.isVisible { return }

        window.removeChildWindow(suggestionsWindow)
        suggestionsWindow.parent?.removeChildWindow(suggestionsWindow)
        suggestionsWindow.orderOut(nil)
    }

    private func layoutSuggestionWindow() {
        guard let window = window, let suggestionsWindow = suggestionsWindowController?.window else {
            os_log("AddressBarTextField: Window not available", log: OSLog.Category.general, type: .error)
            return
        }
        guard let superview = superview else {
            os_log("AddressBarTextField: Superview not available", log: OSLog.Category.general, type: .error)
            return
        }

        let padding = SuggestionsWindowSizes.padding.rawValue
        suggestionsWindow.setFrame(NSRect(x: 0, y: 0, width: superview.frame.width + 2 * padding, height: 0), display: true)

        var point = superview.bounds.origin
        point.x -= padding

        let converted = superview.convert(point, to: nil)
        let screen = window.convertPoint(toScreen: converted)
        suggestionsWindow.setFrameTopLeftPoint(screen)
    }
}

extension AddressBarTextField: NSTextFieldDelegate {

    func controlTextDidEndEditing(_ obj: Notification) {
        suggestionsViewModel.suggestions.stopFetchingSuggestions()

        let textMovement = obj.userInfo?["NSTextMovement"] as? Int
        if textMovement == NSReturnTextMovement {
            confirmStringValue()
        } else {
            updateValue()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        suggestionsViewModel.clearSelection()
        
        value = Value(stringValue: stringValueWithoutSuffix, userTyped: true)
        switch value {
        case .text(let text): suggestionsViewModel.userStringValue = text
        case .url(urlString: let urlString, url: _, userTyped: _): suggestionsViewModel.userStringValue = urlString
        case .suggestion(let suggestionViewModel): suggestionsViewModel.userStringValue = suggestionViewModel.string
        }

        if stringValue == "" {
            hideSuggestionsWindow()
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
        case #selector(NSResponder.deleteBackward(_:)),
             #selector(NSResponder.deleteForward(_:)),
             #selector(NSResponder.deleteToMark(_:)),
             #selector(NSResponder.deleteWordForward(_:)),
             #selector(NSResponder.deleteWordBackward(_:)),
             #selector(NSResponder.deleteToEndOfLine(_:)),
             #selector(NSResponder.deleteToEndOfParagraph(_:)),
             #selector(NSResponder.deleteToBeginningOfLine(_:)),
             #selector(NSResponder.deleteBackwardByDecomposingPreviousCharacter(_:)):
            suggestionsViewModel.clearSelection(); return false
        default:
            return false
        }
    }

}

extension AddressBarTextField: SuggestionsViewControllerDelegate {

    func suggestionsViewControllerDidConfirmSelection(_ suggestionsViewController: SuggestionsViewController) {
        confirmStringValue()
    }

}

//swiftlint:enable type_body_length
