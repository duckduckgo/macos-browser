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
import BrowserServicesKit

// swiftlint:disable type_body_length

final class AddressBarTextField: NSTextField {

    var tabCollectionViewModel: TabCollectionViewModel! {
        didSet {
            subscribeToSelectedTabViewModel()
        }
    }

    var suggestionContainerViewModel: SuggestionContainerViewModel! {
        didSet {
            initSuggestionWindow()
            subscribeToSuggestionItems()
            subscribeToSelectedSuggestionViewModel()
        }
    }

    var isSuggestionWindowVisible: AnyPublisher<Bool, Never> {
        self.publisher(for: \.suggestionWindowController?.window?.isVisible)
            .map { $0 ?? false }
            .eraseToAnyPublisher()
    }

    private var suggestionItemsCancellable: AnyCancellable?
    private var selectedSuggestionViewModelCancellable: AnyCancellable?
    private var selectedTabViewModelCancellable: AnyCancellable?
    private var searchSuggestionsCancellable: AnyCancellable?
    private var addressBarStringCancellable: AnyCancellable?

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
        suggestionContainerViewModel.clearSelection()
        suggestionContainerViewModel.clearUserStringValue()
        hideSuggestionWindow()
    }

    private var isHandlingUserAppendingText = false

    private func subscribeToSuggestionItems() {
        suggestionItemsCancellable = suggestionContainerViewModel.suggestionContainer.$suggestions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
            if self?.suggestionContainerViewModel.suggestionContainer.suggestions?.count ?? 0 > 0 {
                self?.showSuggestionWindow()
            }
        }
    }

    private func subscribeToSelectedSuggestionViewModel() {
        selectedSuggestionViewModelCancellable =
            suggestionContainerViewModel.$selectedSuggestionViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.displaySelectedSuggestionViewModel()
        }
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.subscribeToAddressBarString()
        }
    }

    private func subscribeToAddressBarString() {
        addressBarStringCancellable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            clearValue()
            return
        }
        addressBarStringCancellable = selectedTabViewModel.$addressBarString.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateValue()
            self?.makeMeFirstResponderIfNeeded()
        }
    }

    private func updateValue() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            return
        }

        let addressBarString = selectedTabViewModel.addressBarString
        value = Value(stringValue: addressBarString, userTyped: false)
    }

    private func makeMeFirstResponderIfNeeded() {
        let focusTab = tabCollectionViewModel.selectedTabViewModel?.tab.tabType.focusTabAddressBarWhenSelected ?? true

        if focusTab, stringValue == "" {
            makeMeFirstResponder()
        }
    }

    private func displaySelectedSuggestionViewModel() {
        guard let suggestionWindow = suggestionWindowController?.window else {
            os_log("AddressBarTextField: Window not available", type: .error)
            return
        }
        guard suggestionWindow.isVisible else { return }

        let originalStringValue = suggestionContainerViewModel.userStringValue
        guard let selectedSuggestionViewModel = suggestionContainerViewModel.selectedSuggestionViewModel else {
            if let originalStringValue = originalStringValue {
                value = Value(stringValue: originalStringValue, userTyped: true)
                selectToTheEnd(from: originalStringValue.count)
            } else {
                clearValue()
            }

            return
        }

        value = Value.suggestion(selectedSuggestionViewModel)
        if let originalStringValue = originalStringValue,
           value.string.lowercased().hasPrefix(originalStringValue.lowercased()) {

            selectToTheEnd(from: originalStringValue.count)
        } else {
            // if suggestion doesn't start with the user input select whole string
            currentEditor()?.selectAll(nil)
        }
    }

    private func addressBarEnterPressed() {
        suggestionContainerViewModel.clearUserStringValue()

        let suggestion = suggestionContainerViewModel.selectedSuggestionViewModel?.suggestion
        if NSApp.isCommandPressed {
            openNewTab(selected: NSApp.isShiftPressed, suggestion: suggestion)
        } else {
            navigate(suggestion: suggestion)
        }

        hideSuggestionWindow()
    }

    private func navigate(suggestion: Suggestion?) {
        hideSuggestionWindow()
        updateTabUrl(suggestion: suggestion)

        currentEditor()?.selectAll(self)
    }

    private func updateTabUrl(suggestion: Suggestion?) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        guard let url = makeUrl(suggestion: suggestion,
                                stringValueWithoutSuffix: stringValueWithoutSuffix) else {
            os_log("%s: Making url from address bar string failed", type: .error, className)
            return
        }

        if selectedTabViewModel.tab.url == url {
            Pixel.fire(.refresh(source: .reloadURL))
            selectedTabViewModel.tab.reload()
        } else {
            
            Pixel.fire(.navigation(kind: .init(url: url), source: suggestion != nil ? .suggestion : .addressBar))
            selectedTabViewModel.tab.update(url: url)
        }

        self.window?.makeFirstResponder(nil)
    }

    private func openNewTab(selected: Bool, suggestion: Suggestion?) {
        guard let url = makeUrl(suggestion: suggestion,
                                stringValueWithoutSuffix: stringValueWithoutSuffix) else {
            os_log("%s: Making url from address bar string failed", type: .error, className)
            return
        }

        Pixel.fire(.navigation(kind: .init(url: url), source: suggestion != nil ? .suggestion : .addressBar))
        let tab = Tab(url: url, shouldLoadInBackground: true)
        tabCollectionViewModel.append(tab: tab, selected: selected)
    }

    private func makeUrl(suggestion: Suggestion?, stringValueWithoutSuffix: String) -> URL? {
        let finalUrl: URL?
        switch suggestion {
        case .bookmark(title: _, url: let url, isFavorite: _),
             .historyEntry(title: _, url: let url),
             .website(url: let url):
            finalUrl = url
        case .phrase(phrase: let phrase),
             .unknown(value: let phrase):
            finalUrl = URL.makeSearchUrl(from: phrase)
        case .none:
            finalUrl = URL.makeURL(from: stringValueWithoutSuffix)
        }
        return finalUrl
    }

    // MARK: - Value

    enum Value {
        case text(_ text: String)
        case url(urlString: String, url: URL, userTyped: Bool)
        case suggestion(_ suggestionViewModel: SuggestionViewModel)

        init(stringValue: String, userTyped: Bool) {
            if let url = stringValue.punycodedUrl, url.isValid {
                var stringValue = stringValue
                // display punycoded url in readable form when editing
                if !userTyped,
                   let punycodeDecoded = url.punycodeDecodedString {
                    stringValue = punycodeDecoded
                }
                self = .url(urlString: stringValue, url: url, userTyped: userTyped)
            } else {
                self = .text(stringValue)
            }
        }

        var string: String {
            switch self {
            case .text(let text): return text
            case .url(urlString: let urlString, url: _, userTyped: _): return urlString
            case .suggestion(let suggestionViewModel): return suggestionViewModel.autocompletionString
            }
        }

        var isEmpty: Bool {
            switch self {
            case .text(let text):
                return text.isEmpty
            case .url(urlString: let urlString, url: _, userTyped: _):
                return urlString.isEmpty
            case .suggestion(let suggestion):
                return suggestion.string.isEmpty
            }
        }
    }

    @Published private(set) var value: Value = .text("") {
        didSet {
            suffix = Suffix(value: value)

            if let suffix = suffix {
                let attributedString = NSMutableAttributedString(string: value.string, attributes: Self.textAttributes)
                attributedString.append(suffix.attributedString)
                attributedStringValue = attributedString
            } else {
                self.stringValue = value.string
            }
        }
    }

    // MARK: - Suffixes

    static let textAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
        .foregroundColor: NSColor.textColor,
        .kern: -0.16
    ]

    enum Suffix {
        init?(value: Value) {
            if case .text("") = value {
                return nil
            }

            switch value {
            case .text: self = Suffix.search
            case .url(urlString: _, url: let url, userTyped: let userTyped):
                guard userTyped,
                      let host = url.host
                else { return nil }
                self = Suffix.visit(host: host)
            case .suggestion(let suggestionViewModel):
                switch suggestionViewModel.suggestion {
                case .phrase(phrase: _):
                    self = Suffix.search
                case .website(url: let url),
                     .bookmark(title: _, url: let url, isFavorite: _),
                     .historyEntry(title: _, url: let url):
                    guard let host = url.host else { return nil }
                    self = Suffix.visit(host: host)
                case .unknown(value: _):
                    self = Suffix.search
                }
            }
        }

        case search
        case visit(host: String)

        static let suffixAttributes = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 13, weight: .light),
                                       .foregroundColor: NSColor.addressBarSuffixColor]

        var attributedString: NSAttributedString {
            switch self {
            case .search:
                return NSAttributedString(string: string, attributes: Self.suffixAttributes)
            case .visit(host: _):
                return NSAttributedString(string: string, attributes: Self.suffixAttributes)
            }
        }

        static let searchSuffix = " – \(UserText.addressBarSearchSuffix)"
        static let visitSuffix = " – \(UserText.addressBarVisitSuffix)"

        var string: String {
            switch self {
            case .search:
                return "\(Self.searchSuffix)"
            case .visit(host: let host):
                return "\(Self.visitSuffix) \(host)"
            }
        }
    }

    private var suffix: Suffix?

    private var stringValueWithoutSuffix: String {
        if let suffix = suffix {
            return stringValue.drop(suffix: suffix.string)
        } else {
            return stringValue
        }
    }

    // MARK: - Cursor & Selection

    private func selectToTheEnd(from offset: Int) {
        guard let currentEditor = currentEditor() else {
            os_log("AddressBarTextField: Current editor not available", type: .error)
            return
        }
        let string = currentEditor.string
        let startIndex = string.index(string.startIndex, offsetBy: string.count >= offset ? offset : 0)
        let endIndex = string.index(string.endIndex, offsetBy: -(suffix?.string.count ?? 0))

        currentEditor.selectedRange = string.nsRange(from: startIndex..<endIndex)
    }

    func filterSuffix(fromSelectionRange range: NSRange, for stringValue: String) -> NSRange {
        let suffixStart = stringValue.utf16.count - (suffix?.string.utf16.count ?? 0)
        let currentSelectionEnd = range.location + range.length
        guard suffixStart >= 0,
              currentSelectionEnd > suffixStart
        else { return range }

        let newLocation = min(range.location, suffixStart)
        let newMaxLength = suffixStart - newLocation
        let newLength = min(newMaxLength, currentSelectionEnd - newLocation)

        return NSRange(location: newLocation, length: newLength)
    }

    // MARK: - Suggestion window

    enum SuggestionWindowSizes {
        static let padding = CGPoint(x: -20, y: 1)
    }

    @objc dynamic private var suggestionWindowController: NSWindowController?
    private lazy var suggestionViewController: SuggestionViewController = {
        NSStoryboard.suggestion.instantiateController(identifier: "SuggestionViewController") { coder in
            let suggestionViewController = SuggestionViewController(coder: coder,
                                                                    suggestionContainerViewModel: self.suggestionContainerViewModel)
            suggestionViewController?.delegate = self
            return suggestionViewController
        }
    }()

    private func initSuggestionWindow() {
        let windowController = NSStoryboard.suggestion
            .instantiateController(withIdentifier: "SuggestionWindowController") as? NSWindowController

        windowController?.contentViewController = suggestionViewController
        self.suggestionWindowController = windowController
    }

    private func suggestionsContainBookmarkOrFavorite() -> (hasBookmark: Bool, hasFavorite: Bool) {
        var result = (hasBookmark: false, hasFavorite: false)
        for suggestion in self.suggestionContainerViewModel.suggestionContainer.suggestions ?? [] {
            guard case .bookmark(title: _, url: _, isFavorite: let isFavorite) = suggestion else { continue }

            if isFavorite {
                result.hasFavorite = true
            } else {
                result.hasBookmark = true
            }

            if result.hasFavorite && result.hasBookmark {
                break
            }
        }
        return result
    }

    private func showSuggestionWindow() {
        guard let window = window, let suggestionWindow = suggestionWindowController?.window else {
            os_log("AddressBarTextField: Window not available", type: .error)
            return
        }

        Pixel.fire(.suggestionsDisplayed(suggestionsContainBookmarkOrFavorite()))

        guard !suggestionWindow.isVisible, window.firstResponder == currentEditor() else { return }

        window.addChildWindow(suggestionWindow, ordered: .above)
        layoutSuggestionWindow()
        postSuggestionWindowOpenNotification()
    }

    private func postSuggestionWindowOpenNotification() {
        NotificationCenter.default.post(name: .suggestionWindowOpen, object: nil)
    }

    private func hideSuggestionWindow() {
        guard let window = window, let suggestionWindow = suggestionWindowController?.window else {
            os_log("AddressBarTextField: Window not available", type: .error)
            return
        }

        if !suggestionWindow.isVisible { return }

        window.removeChildWindow(suggestionWindow)
        suggestionWindow.parent?.removeChildWindow(suggestionWindow)
        suggestionWindow.orderOut(nil)
    }

    private func layoutSuggestionWindow() {
        guard let window = window, let suggestionWindow = suggestionWindowController?.window else {
            os_log("AddressBarTextField: Window not available", type: .error)
            return
        }
        guard let superview = superview else {
            os_log("AddressBarTextField: Superview not available", type: .error)
            return
        }

        let padding = SuggestionWindowSizes.padding
        suggestionWindow.setFrame(NSRect(x: 0, y: 0, width: superview.frame.width - 2 * padding.x, height: 0), display: true)

        var point = superview.bounds.origin
        point.x += padding.x
        point.y += padding.y

        let converted = superview.convert(point, to: nil)
        let rounded = CGPoint(x: Int(converted.x), y: Int(converted.y))

        let screen = window.convertPoint(toScreen: rounded)
        suggestionWindow.setFrameTopLeftPoint(screen)

        // pixel-perfect window adjustment for fractional points
        suggestionViewController.pixelPerfectConstraint.constant = converted.x - rounded.x
    }

}

extension Notification.Name {

    static let suggestionWindowOpen = Notification.Name("suggestionWindowOpen")

}

extension AddressBarTextField: NSTextFieldDelegate {

    func controlTextDidEndEditing(_ obj: Notification) {
        suggestionContainerViewModel.clearUserStringValue()
        hideSuggestionWindow()
        updateValue()
    }

    func controlTextDidChange(_ obj: Notification) {
        let stringValueWithoutSuffix = self.stringValueWithoutSuffix

        // if user continues typing letters from displayed Suggestion
        // don't blink and keep the Suggestion displayed
        if case .suggestion(let suggestion) = self.value,
           stringValueWithoutSuffix.hasPrefix(suggestion.userStringValue),
           suggestion.autocompletionString.hasPrefix(stringValueWithoutSuffix),
           let editor = currentEditor(),
           editor.selectedRange.location == stringValueWithoutSuffix.utf16.count {

            self.value = .suggestion(SuggestionViewModel(suggestion: suggestion.suggestion,
                                                         userStringValue: stringValueWithoutSuffix))
            self.selectToTheEnd(from: stringValueWithoutSuffix.count)

        } else {
            suggestionContainerViewModel.clearSelection()
            self.value = Value(stringValue: stringValueWithoutSuffix, userTyped: true)
        }

        if stringValue.isEmpty {
            suggestionContainerViewModel.clearUserStringValue()
            hideSuggestionWindow()
        } else {
            suggestionContainerViewModel.setUserStringValue(stringValueWithoutSuffix,
                                                            userAppendedStringToTheEnd: isHandlingUserAppendingText)
        }

        // reset user typed flag for the next didChange event
        isHandlingUserAppendingText = false
    }

    func textView(_ textView: NSTextView, userTypedString typedString: String, at range: NSRange) {
        let userTypedLength = suggestionContainerViewModel.userStringValue?.utf16.count ?? 0
        let currentValueLength = self.stringValueWithoutSuffix.utf16.count
        let selectedSuggestionRange = NSRange(location: userTypedLength, length: currentValueLength - userTypedLength)
        assert(selectedSuggestionRange.upperBound <= currentValueLength)

        // if user is typing in the end of current value or replacing selected suggestion range
        // or replaces the whole string
        if selectedSuggestionRange == range || range.length >= currentValueLength || range.location == NSNotFound {
            // we'll select the first suggested item
            isHandlingUserAppendingText = true
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if NSApp.isReturnOrEnterPressed {
            self.addressBarEnterPressed()
            return true
        }

        guard suggestionWindowController?.window?.isVisible == true else {
            return false
        }

        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            suggestionContainerViewModel.selectNextIfPossible(); return true
        case #selector(NSResponder.moveUp(_:)):
            suggestionContainerViewModel.selectPreviousIfPossible(); return true
        case #selector(NSResponder.deleteBackward(_:)),
             #selector(NSResponder.deleteForward(_:)),
             #selector(NSResponder.deleteToMark(_:)),
             #selector(NSResponder.deleteWordForward(_:)),
             #selector(NSResponder.deleteWordBackward(_:)),
             #selector(NSResponder.deleteToEndOfLine(_:)),
             #selector(NSResponder.deleteToEndOfParagraph(_:)),
             #selector(NSResponder.deleteToBeginningOfLine(_:)),
             #selector(NSResponder.deleteBackwardByDecomposingPreviousCharacter(_:)):
            suggestionContainerViewModel.clearSelection(); return false
        default:
            return false
        }
    }

}

extension AddressBarTextField: SuggestionViewControllerDelegate {

    func suggestionViewControllerDidConfirmSelection(_ suggestionViewController: SuggestionViewController) {
        let suggestion = suggestionContainerViewModel.selectedSuggestionViewModel?.suggestion
        if NSApp.isCommandPressed {
            openNewTab(selected: NSApp.isShiftPressed, suggestion: suggestion)
            return
        }
        navigate(suggestion: suggestion)
    }

    func shouldCloseSuggestionWindow(forMouseEvent event: NSEvent) -> Bool {
        // don't hide suggestions if clicking somewhere inside the Address Bar view
        return superview?.isMouseLocationInsideBounds(event.locationInWindow) != true
    }
}

extension AddressBarTextField: NSTextViewDelegate {
    func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange _: NSRange, toCharacterRange range: NSRange) -> NSRange {
        return self.filterSuffix(fromSelectionRange: range, for: textView.string)
    }
}

final class AddressBarTextEditor: NSTextView {

    override func selectionRange(forProposedRange proposedCharRange: NSRange, granularity: NSSelectionGranularity) -> NSRange {
        guard let delegate = delegate as? AddressBarTextField else {
            os_log("AddressBarTextEditor: unexpected kind of delegate")
            return super.selectionRange(forProposedRange: proposedCharRange, granularity: granularity)
        }

        let string = self.string
        var range: NSRange
        switch granularity {
        case .selectByParagraph:
            // select all and then adjust by removing suffix
            range = self.string.nsRange(from: string.startIndex..<string.endIndex)

        case .selectByWord:
            range = delegate.filterSuffix(fromSelectionRange: proposedCharRange, for: self.string)
            // if selection for word included suffix, move one character before adjusted to select last word w/o suffix
            if range != proposedCharRange,
               range.location > 0 {
                range.location -= 1
            }
            // select word and then adjust by removing suffix
            range = super.selectionRange(forProposedRange: range, granularity: granularity)

        case .selectByCharacter: fallthrough
        @unknown default:
            // adjust caret location only
            range = proposedCharRange
        }
        return delegate.filterSuffix(fromSelectionRange: range, for: self.string)
    }

    override func characterIndexForInsertion(at point: NSPoint) -> Int {
        let index = super.characterIndexForInsertion(at: point)
        let adjustedRange = selectionRange(forProposedRange: NSRange(location: index, length: 0),
                                           granularity: .selectByCharacter)
        return adjustedRange.location
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        defer {
            super.insertText(string, replacementRange: replacementRange)
        }

        guard let delegate = delegate as? AddressBarTextField else {
            os_log("AddressBarTextEditor: unexpected kind of delegate")
            return
        }
        guard let string = string as? String else { return }

        delegate.textView(self, userTypedString: string, at: replacementRange)
    }
}

final class AddressBarTextFieldCell: NSTextFieldCell {
    lazy var customEditor = AddressBarTextEditor()

    override func fieldEditor(for controlView: NSView) -> NSTextView? {
        return customEditor
    }
}

// swiftlint:enable type_body_length

fileprivate extension NSStoryboard {
    static let suggestion = NSStoryboard(name: "Suggestion", bundle: .main)
}
