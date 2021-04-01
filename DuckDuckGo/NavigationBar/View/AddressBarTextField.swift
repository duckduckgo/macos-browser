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

// swiftlint:disable type_body_length

final class AddressBarTextField: NSTextField {

    var tabCollectionViewModel: TabCollectionViewModel! {
        didSet {
            subscribeToSelectedTabViewModel()
        }
    }

    var suggestionsViewModel: SuggestionsViewModel! {
        didSet {
            initSuggestionsWindow()
            subscribeToSuggestionItems()
            subscribeToSelectedSuggestionViewModel()
        }
    }

    var isSuggestionsWindowVisible: AnyPublisher<Bool, Never> {
        self.publisher(for: \.suggestionsWindowController?.window?.isVisible)
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
        suggestionsViewModel.clearSelection()
        suggestionsViewModel.suggestions.stopFetchingSuggestions()
        suggestionsViewModel.userStringValue = nil
        hideSuggestionsWindow()
    }

    private func subscribeToSuggestionItems() {
        suggestionItemsCancellable = suggestionsViewModel.suggestions.$items.receive(on: DispatchQueue.main).sink { [weak self] _ in
            if self?.suggestionsViewModel.suggestions.items?.count ?? 0 > 0 {
                self?.showSuggestionsWindow()
            }
        }
    }

    private func subscribeToSelectedSuggestionViewModel() {
        selectedSuggestionViewModelCancellable =
            suggestionsViewModel.$selectedSuggestionViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
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
        if stringValue == "" {
            makeMeFirstResponder()
        }
    }

    private func displaySelectedSuggestionViewModel() {
        guard let suggestionsWindow = suggestionsWindowController?.window else {
            os_log("AddressBarTextField: Window not available", type: .error)
            return
        }
        guard suggestionsWindow.isVisible else { return }

        let originalStringValue = suggestionsViewModel.userStringValue
        guard let selectedSuggestionViewModel = suggestionsViewModel.selectedSuggestionViewModel else {
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
           value.string.hasPrefix(originalStringValue) {

            selectToTheEnd(from: originalStringValue.count)
        } else {
            // if suggestion doesn't start with the user input select whole string
            currentEditor()?.selectAll(nil)
        }
    }

    private func addressBarEnterPressed() {
        let suggestionUsed = suggestionsViewModel.selectedSuggestionViewModel != nil
        suggestionsViewModel.suggestions.stopFetchingSuggestions()
        hideSuggestionsWindow()

        if NSApp.isCommandPressed {
            openNewTab(selected: NSApp.isShiftPressed, suggestionUsed: suggestionUsed)
        } else {
            navigate(suggestionUsed: suggestionUsed)
        }
    }

    private func navigate(suggestionUsed: Bool) {
        hideSuggestionsWindow()
        updateTabUrl(suggestionUsed: suggestionUsed)
        currentEditor()?.selectAll(self)
    }

    private func updateTabUrl(suggestionUsed: Bool) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }
        guard let url = URL.makeURL(from: stringValueWithoutSuffix) else {
            os_log("%s: Making url from address bar string failed", type: .error, className)
            return
        }

        if selectedTabViewModel.tab.url == url {
            Pixel.fire(.refresh(source: .reloadURL))
            selectedTabViewModel.tab.reload()
        } else {
            
            Pixel.fire(.navigation(kind: .init(url: url), source: suggestionUsed ? .suggestion : .addressBar))
            selectedTabViewModel.tab.update(url: url)
        }

        self.window?.makeFirstResponder(nil)
    }

    private func openNewTab(selected: Bool, suggestionUsed: Bool) {
        guard let url = URL.makeURL(from: stringValueWithoutSuffix) else {
            os_log("%s: Making url from address bar string failed", type: .error, className)
            return
        }

        Pixel.fire(.navigation(kind: .init(url: url), source: suggestionUsed ? .suggestion : .addressBar))
        let tab = Tab(url: url, shouldLoadInBackground: true)
        tabCollectionViewModel.append(tab: tab, selected: selected)
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
            case .suggestion(let suggestionViewModel): return suggestionViewModel.string
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
                case .website(url: let url):
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

    // MARK: - Suggestions window

    enum SuggestionsWindowSizes {
        static let padding = CGPoint(x: -20, y: 1)
    }

    @objc dynamic private var suggestionsWindowController: NSWindowController?
    private lazy var suggestionsViewController: SuggestionsViewController = {
        NSStoryboard.suggestions.instantiateController(identifier: "SuggestionsViewController") { coder in
            let suggestionsViewController = SuggestionsViewController(coder: coder,
                                                                      suggestionsViewModel: self.suggestionsViewModel)
            suggestionsViewController?.delegate = self
            return suggestionsViewController
        }
    }()

    private func initSuggestionsWindow() {
        let windowController = NSStoryboard.suggestions
            .instantiateController(withIdentifier: "SuggestionsWindowController") as? NSWindowController

        windowController?.contentViewController = suggestionsViewController
        self.suggestionsWindowController = windowController
    }

    private func suggestionsContainBookmarkOrFavorite() -> (hasBookmark: Bool, hasFavorite: Bool) {
        var result = (hasBookmark: false, hasFavorite: false)
        // fix this to correctly search suggested bookmarks/favorites
        return result
    }

    private func showSuggestionsWindow() {
        guard let window = window, let suggestionsWindow = suggestionsWindowController?.window else {
            os_log("AddressBarTextField: Window not available", type: .error)
            return
        }

        Pixel.fire(.suggestionsDisplayed(suggestionsContainBookmarkOrFavorite()))

        guard !suggestionsWindow.isVisible, window.firstResponder == currentEditor() else { return }

        window.addChildWindow(suggestionsWindow, ordered: .above)
        layoutSuggestionWindow()
        postSuggestionWindowOpenNotification()
    }

    private func postSuggestionWindowOpenNotification() {
        NotificationCenter.default.post(name: .suggestionWindowOpen, object: nil)
    }

    private func hideSuggestionsWindow() {
        guard let window = window, let suggestionsWindow = suggestionsWindowController?.window else {
            os_log("AddressBarTextField: Window not available", type: .error)
            return
        }

        if !suggestionsWindow.isVisible { return }

        window.removeChildWindow(suggestionsWindow)
        suggestionsWindow.parent?.removeChildWindow(suggestionsWindow)
        suggestionsWindow.orderOut(nil)
    }

    private func layoutSuggestionWindow() {
        guard let window = window, let suggestionsWindow = suggestionsWindowController?.window else {
            os_log("AddressBarTextField: Window not available", type: .error)
            return
        }
        guard let superview = superview else {
            os_log("AddressBarTextField: Superview not available", type: .error)
            return
        }

        let padding = SuggestionsWindowSizes.padding
        suggestionsWindow.setFrame(NSRect(x: 0, y: 0, width: superview.frame.width - 2 * padding.x, height: 0), display: true)

        var point = superview.bounds.origin
        point.x += padding.x
        point.y += padding.y

        let converted = superview.convert(point, to: nil)
        let rounded = CGPoint(x: Int(converted.x), y: Int(converted.y))

        let screen = window.convertPoint(toScreen: rounded)
        suggestionsWindow.setFrameTopLeftPoint(screen)

        // pixel-perfect window adjustment for fractional points
        suggestionsViewController.pixelPerfectConstraint.constant = converted.x - rounded.x
    }

}

extension Notification.Name {

    static let suggestionWindowOpen = Notification.Name("suggestionWindowOpen")

}

extension AddressBarTextField: NSTextFieldDelegate {

    func controlTextDidEndEditing(_ obj: Notification) {
        suggestionsViewModel.suggestions.stopFetchingSuggestions()
        hideSuggestionsWindow()
        updateValue()
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
            suggestionsViewModel.suggestions.stopFetchingSuggestions()
            hideSuggestionsWindow()
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if NSApp.isReturnOrEnterPressed {
            self.addressBarEnterPressed()
            return true
        }

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
        if NSApp.isCommandPressed {
            openNewTab(selected: NSApp.isShiftPressed, suggestionUsed: true)
            return
        }
        navigate(suggestionUsed: true)
    }

    func shouldCloseSuggestionsWindow(forMouseEvent event: NSEvent) -> Bool {
        // don't hide suggestions if clicking somewhere inside the Address Bar view
        if let screenPoint = event.window?.convertPoint(toScreen: event.locationInWindow),
           let point = self.window?.convertPoint(fromScreen: screenPoint),
           superview!.bounds.contains(superview!.convert(point, from: nil)) {

            return false
        }

        return true
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

}

final class AddressBarTextFieldCell: NSTextFieldCell {
    lazy var customEditor = AddressBarTextEditor()

    override func fieldEditor(for controlView: NSView) -> NSTextView? {
        return customEditor
    }
}

// swiftlint:enable type_body_length

fileprivate extension NSStoryboard {
    static let suggestions = NSStoryboard(name: "Suggestions", bundle: .main)
}
