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

protocol AddressBarTextFieldDelegate: AnyObject {

    func adressBarTextField(_ addressBarTextField: AddressBarTextField, didChangeValue value: AddressBarTextField.Value)

}

// swiftlint:disable:next type_body_length
final class AddressBarTextField: NSTextField {

    weak var addressBarTextFieldDelegate: AddressBarTextFieldDelegate?

    var tabCollectionViewModel: TabCollectionViewModel! {
        didSet {
            subscribeToSelectedTabViewModel()
        }
    }

    var suggestionContainerViewModel: SuggestionContainerViewModel? {
        didSet {
            guard suggestionContainerViewModel != nil else { return }
            initSuggestionWindow()
            subscribeToSuggestionResult()
            subscribeToSelectedSuggestionViewModel()
        }
    }

    var suggestionWindowVisible: AnyPublisher<Bool, Never> {
        self.publisher(for: \.suggestionWindowController?.window?.isVisible)
            .map { $0 ?? false }
            .eraseToAnyPublisher()
    }

    var isSuggestionWindowVisible: Bool {
        suggestionWindowController?.window?.isVisible == true
    }

    private var suggestionResultCancellable: AnyCancellable?
    private var selectedSuggestionViewModelCancellable: AnyCancellable?
    private var selectedTabViewModelCancellable: AnyCancellable?
    private var searchSuggestionsCancellable: AnyCancellable?
    private var addressBarStringCancellable: AnyCancellable?
    private var contentTypeCancellable: AnyCancellable?

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
        suggestionContainerViewModel?.clearSelection()
        suggestionContainerViewModel?.clearUserStringValue()
        hideSuggestionWindow()
    }

    private var isHandlingUserAppendingText = false

    private func subscribeToSuggestionResult() {
        suggestionResultCancellable = suggestionContainerViewModel?.suggestionContainer.$result
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.suggestionContainerViewModel?.suggestionContainer.result?.count ?? 0 > 0 {
                    self.showSuggestionWindow()
                }
            }
    }

    private func subscribeToSelectedSuggestionViewModel() {
        selectedSuggestionViewModelCancellable =
            suggestionContainerViewModel?.$selectedSuggestionViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.displaySelectedSuggestionViewModel()
        }
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.restoreValueIfPossible()
            self?.subscribeToAddressBarString()
            self?.subscribeToContentType()
        }
    }

    private func subscribeToContentType() {
        contentTypeCancellable = tabCollectionViewModel.selectedTabViewModel?
            .tab.$content .receive(on: DispatchQueue.main).sink { [weak self] contentType in
            self?.font = .systemFont(ofSize: contentType == .homePage ? 15 : 13)
        }
    }

    private func subscribeToAddressBarString() {
        addressBarStringCancellable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            clearValue()
            return
        }
        addressBarStringCancellable = selectedTabViewModel.$addressBarString.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateValue()
        }
    }

    private func updateValue() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            return
        }

        let addressBarString = selectedTabViewModel.addressBarString
        let isSearch = selectedTabViewModel.tab.content.url?.isDuckDuckGoSearch ?? false
        value = Value(stringValue: addressBarString, userTyped: false, isSearch: isSearch)
    }

    private func saveValue() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            return
        }

        selectedTabViewModel.lastAddressBarTextFieldValue = value
    }

    private func restoreValueIfPossible() {
        func restoreValue(_ value: AddressBarTextField.Value) {
            self.value = value
            currentEditor()?.selectAll(self)
        }

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            return
        }

        let lastAddressBarTextFieldValue = selectedTabViewModel.lastAddressBarTextFieldValue

        switch lastAddressBarTextFieldValue {
        case .text(let text):
            if !text.isEmpty {
                restoreValue(lastAddressBarTextFieldValue ?? Value(stringValue: "", userTyped: true))
            } else {
                updateValue()
            }
        case .suggestion(let suggestionViewModel):
            let suggestion = suggestionViewModel.suggestion
            switch suggestion {
            case .website, .bookmark, .historyEntry:
                restoreValue(Value(stringValue: suggestionViewModel.autocompletionString, userTyped: true))
            case .phrase(phrase: let phase):
                restoreValue(Value.text(phase))
            default:
                updateValue()
            }
        case .url(urlString: let urlString, url: _, userTyped: true):
            restoreValue(Value(stringValue: urlString, userTyped: true))
        default:
            updateValue()
        }
    }

    func escapeKeyDown() {
        if suggestionWindowController?.window?.isVisible ?? false {
            hideSuggestionWindow()
            return
        }

        clearValue()
        updateValue()
    }

    private func displaySelectedSuggestionViewModel() {
        guard let suggestionWindow = suggestionWindowController?.window else {
            os_log("AddressBarTextField: Window not available", type: .error)
            return
        }
        guard suggestionWindow.isVisible else { return }

        let originalStringValue = suggestionContainerViewModel?.userStringValue
        guard let selectedSuggestionViewModel = suggestionContainerViewModel?.selectedSuggestionViewModel else {
            if let originalStringValue = originalStringValue {
                value = Value(stringValue: originalStringValue, userTyped: true)
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

    fileprivate func handlePastedURL() {
        handleTextDidChange()
        selectToTheEnd(from: stringValueWithoutSuffix.count)
    }

    private func addressBarEnterPressed() {
        suggestionContainerViewModel?.clearUserStringValue()

        let suggestion = suggestionContainerViewModel?.selectedSuggestionViewModel?.suggestion
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

    private func updateTabUrlWithUrl(_ providedUrl: URL, suggestion: Suggestion?) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        var url = providedUrl

        // keep current search mode
        if url.isDuckDuckGoSearch,
           let oldURL = selectedTabViewModel.tab.content.url,
            oldURL.isDuckDuckGoSearch {
            if let ia = oldURL.getParameter(named: URL.DuckDuckGoParameters.ia.rawValue) {
                url = url.removingParameters(named: [URL.DuckDuckGoParameters.ia.rawValue])
                    .appendingParameter(name: URL.DuckDuckGoParameters.ia.rawValue, value: ia)
            }
            if let iax = oldURL.getParameter(named: URL.DuckDuckGoParameters.iax.rawValue) {
                url = url.removingParameters(named: [URL.DuckDuckGoParameters.iax.rawValue])
                    .appendingParameter(name: URL.DuckDuckGoParameters.iax.rawValue, value: iax)
            }
        }

        if selectedTabViewModel.tab.content.url == url {
            selectedTabViewModel.reload()
        } else {
            selectedTabViewModel.tab.update(url: url)
        }

        self.window?.makeFirstResponder(nil)
    }

    private func updateTabUrl(suggestion: Suggestion?) {
        makeUrl(suggestion: suggestion,
                stringValueWithoutSuffix: stringValueWithoutSuffix,
                completion: { [weak self] url, isUpgraded in
            guard let url = url else { return }

            if isUpgraded { self?.updateTabUpgradedToUrl(url) }
            self?.updateTabUrlWithUrl(url, suggestion: suggestion)
        })
    }

    private func updateTabUpgradedToUrl(_ url: URL?) {
        if url == nil { return }
        let tab = tabCollectionViewModel.selectedTabViewModel?.tab
        tab?.setMainFrameConnectionUpgradedTo(url)
    }

    private func openNewTabWithUrl(_ providedUrl: URL?, selected: Bool, suggestion: Suggestion?) {
        guard let url = providedUrl else {
            os_log("%s: Making url from address bar string failed", type: .error, className)
            return
        }

        let tab = Tab(content: .url(url), shouldLoadInBackground: true)
        tabCollectionViewModel.append(tab: tab, selected: selected)
    }

    private func openNewTab(selected: Bool, suggestion: Suggestion?) {
        makeUrl(suggestion: suggestion,
                stringValueWithoutSuffix: stringValueWithoutSuffix,
                completion: { [weak self] url, isUpgraded in
                    if isUpgraded { self?.updateTabUpgradedToUrl(url) }
                    self?.openNewTabWithUrl(url, selected: selected, suggestion: suggestion)
                })
    }

    private func makeUrl(suggestion: Suggestion?, stringValueWithoutSuffix: String, completion: @escaping (URL?, Bool) -> Void) {
        let finalUrl: URL?
        switch suggestion {
        case .bookmark(title: _, url: let url, isFavorite: _, allowedInTopHits: _),
             .historyEntry(title: _, url: let url, allowedInTopHits: _),
             .website(url: let url):
            finalUrl = url
        case .phrase(phrase: let phrase),
             .unknown(value: let phrase):
            finalUrl = URL.makeSearchUrl(from: phrase)
        case .none:
            finalUrl = URL.makeURL(from: stringValueWithoutSuffix)
        }

        guard let url = finalUrl else {
            completion(finalUrl, false)
            return
        }

        upgradeToHttps(url: url, completion: completion)
    }

    private func upgradeToHttps(url: URL, completion: @escaping (URL?, Bool) -> Void) {
        Task {
            let result = await PrivacyFeatures.httpsUpgrade.upgrade(url: url)
            switch result {
            case let .success(upgradedUrl):
                completion(upgradedUrl, true)
            case .failure:
                completion(url, false)
            }
        }
    }

    // MARK: - Value

    enum Value {
        case text(_ text: String)
        case url(urlString: String, url: URL, userTyped: Bool)
        case suggestion(_ suggestionViewModel: SuggestionViewModel)

        init(stringValue: String, userTyped: Bool, isSearch: Bool = false) {
            if let url = URL(trimmedAddressBarString: stringValue), url.isValid {
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
            case .text(let text):
                return text
            case .url(urlString: let urlString, url: _, userTyped: _):
                return urlString
            case .suggestion(let suggestionViewModel):
                let autocompletionString = suggestionViewModel.autocompletionString
                if autocompletionString.lowercased()
                    .hasPrefix(suggestionViewModel.userStringValue.lowercased()) {
                    // keep user input capitalization
                    let suffixLength = autocompletionString.count - suggestionViewModel.userStringValue.count
                    return suggestionViewModel.userStringValue + autocompletionString.suffix(suffixLength)
                }
                return autocompletionString
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

        var isText: Bool {
            if case .text = self {
                return true
            }
            return false
        }
    }

    @Published private(set) var value: Value = .text("") {
        didSet {
            saveValue()

            suffix = Suffix(value: value)

            if let suffix = suffix {
                let attributedString = NSMutableAttributedString(string: value.string, attributes: makeTextAttributes())
                attributedString.append(suffix.toAttributedString(size: isHomePage ? 15 : 13))
                attributedStringValue = attributedString
            } else {
                self.stringValue = value.string
            }

            addressBarTextFieldDelegate?.adressBarTextField(self, didChangeValue: value)
        }
    }

    // MARK: - Suffixes

    var isHomePage: Bool {
        tabCollectionViewModel.selectedTabViewModel?.tab.content == .homePage
    }

    func makeTextAttributes() -> [NSAttributedString.Key: Any] {
        let size: CGFloat = isHomePage ? 15 : 13
        return [
           .font: NSFont.systemFont(ofSize: size, weight: .regular),
           .foregroundColor: NSColor.textColor,
           .kern: -0.16
       ]
    }

    enum Suffix {
        init?(value: Value) {
            if case .text("") = value {
                return nil
            }

            switch value {
            case .text: self = Suffix.search
            case .url(urlString: _, url: let url, userTyped: let userTyped):
                guard userTyped,
                      let host = url.root?.toString(decodePunycode: true, dropScheme: true, dropTrailingSlash: true)
                else { return nil }
                self = Suffix.visit(host: host)
            case .suggestion(let suggestionViewModel):
                self.init(suggestionViewModel: suggestionViewModel)
            }
        }

        init?(suggestionViewModel: SuggestionViewModel) {
            switch suggestionViewModel.suggestion {
            case .phrase:
                self = Suffix.search
            case .website(url: let url):
                guard let host = url.root?.toString(decodePunycode: true, dropScheme: true, dropTrailingSlash: true) else {
                    return nil
                }
                self = Suffix.visit(host: host)

            case .bookmark(title: _, url: let url, isFavorite: _, allowedInTopHits: _),
                 .historyEntry(title: _, url: let url, allowedInTopHits: _):
                if let title = suggestionViewModel.title,
                   !title.isEmpty,
                   suggestionViewModel.autocompletionString != title {
                    self = .title(title)
                } else if let host = url.root?.toString(decodePunycode: true, dropScheme: true, needsWWW: false, dropTrailingSlash: true) {
                    self = .visit(host: host)
                } else {
                    self = .url(url)
                }

            case .unknown:
                self = Suffix.search
            }
        }

        case search
        case visit(host: String)
        case url(URL)
        case title(String)

        func toAttributedString(size: CGFloat) -> NSAttributedString {
            let attrs = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: size, weight: .light),
                         .foregroundColor: NSColor.addressBarSuffixColor]
            return NSAttributedString(string: string, attributes: attrs)
        }

        static let searchSuffix = " – \(UserText.searchDuckDuckGoSuffix)"
        static let visitSuffix = " – \(UserText.addressBarVisitSuffix)"

        var string: String {
            switch self {
            case .search:
                return Self.searchSuffix
            case .visit(host: let host):
                return "\(Self.visitSuffix) \(host)"
            case .url(let url):
                if url.isDuckDuckGoSearch {
                    return Self.searchSuffix
                } else {
                    return " – " + url.toString(decodePunycode: false,
                                                dropScheme: true,
                                                needsWWW: false,
                                                dropTrailingSlash: false)
                }
            case .title(let title):
                return " – " + title
            }
        }
    }

    private var suffix: Suffix?

    private var stringValueWithoutSuffix: String {
        if let suffix = suffix {
            return stringValue.dropping(suffix: suffix.string)
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
                                                                    suggestionContainerViewModel: self.suggestionContainerViewModel!)
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

    private func suggestionsContainLocalItems() -> SuggestionListChacteristics {
        var characteristics = SuggestionListChacteristics(hasBookmark: false, hasFavorite: false, hasHistoryEntry: false)
        for suggestion in self.suggestionContainerViewModel?.suggestionContainer.result?.all ?? [] {
            if case .bookmark(title: _, url: _, isFavorite: let isFavorite, allowedInTopHits: _) = suggestion {
                if isFavorite {
                    characteristics.hasFavorite = true
                } else {
                    characteristics.hasBookmark = true
                }
            } else if case .historyEntry = suggestion {
                characteristics.hasHistoryEntry = true
            } else {
                continue
            }

            if characteristics.hasFavorite && characteristics.hasBookmark && characteristics.hasHistoryEntry {
                break
            }
        }
        return characteristics
    }

    private func showSuggestionWindow() {
        guard let window = window, let suggestionWindow = suggestionWindowController?.window else {
            os_log("AddressBarTextField: Window not available", type: .error)
            return
        }

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
            return
        }

        if !suggestionWindow.isVisible { return }

        window.removeChildWindow(suggestionWindow)
        suggestionWindow.parent?.removeChildWindow(suggestionWindow)
        suggestionWindow.orderOut(nil)
    }

    private func layoutSuggestionWindow() {
        guard let window = window, let suggestionWindow = suggestionWindowController?.window else {
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

    // MARK: - Menu Actions

    @objc private func pasteAndGo(_ menuItem: NSMenuItem) {
        guard let pasteboardString = NSPasteboard.general.string(forType: .string),
              let url = URL(trimmedAddressBarString: pasteboardString.trimmingWhitespace()) else {
                  assertionFailure("Pasteboard doesn't contain URL")
                  return
              }

        tabCollectionViewModel.selectedTabViewModel?.tab.update(url: url)
    }

    @objc private func pasteAndSearch(_ menuItem: NSMenuItem) {
        guard let pasteboardString = NSPasteboard.general.string(forType: .string),
              let searchURL = URL.makeSearchUrl(from: pasteboardString) else {
                  assertionFailure("Can't create search URL from pasteboard string")
                  return
              }

        tabCollectionViewModel.selectedTabViewModel?.tab.update(url: searchURL)
    }

    @objc private func toggleAutocomplete(_ menuItem: NSMenuItem) {
        AppearancePreferences.shared.showAutocompleteSuggestions.toggle()

        let shouldShowAutocomplete = AppearancePreferences.shared.showAutocompleteSuggestions

        menuItem.state = shouldShowAutocomplete ? .on : .off

        if shouldShowAutocomplete {
            handleTextDidChange()
        } else {
            hideSuggestionWindow()
        }
    }

    @objc private func toggleShowFullWebsiteAddress(_ menuItem: NSMenuItem) {
        AppearancePreferences.shared.showFullURL.toggle()

        let shouldShowFullURL = AppearancePreferences.shared.showFullURL
        menuItem.state = shouldShowFullURL ? .on : .off
    }

}

extension Notification.Name {

    static let suggestionWindowOpen = Notification.Name("suggestionWindowOpen")

}

extension AddressBarTextField: NSTextFieldDelegate {

    func controlTextDidEndEditing(_ obj: Notification) {
        suggestionContainerViewModel?.clearUserStringValue()
        hideSuggestionWindow()
    }

    func controlTextDidChange(_ obj: Notification) {
        handleTextDidChange()
    }

    private func handleTextDidChange() {
        let stringValueWithoutSuffix = self.stringValueWithoutSuffix

        // if user continues typing letters from displayed Suggestion
        // don't blink and keep the Suggestion displayed
        if isHandlingUserAppendingText,
           case .suggestion(let suggestion) = self.value,
           // disable autocompletion when user entered Space
           !stringValueWithoutSuffix.contains(" "),
           stringValueWithoutSuffix.hasPrefix(suggestion.userStringValue),
           suggestion.autocompletionString.hasPrefix(stringValueWithoutSuffix),
           let editor = currentEditor(),
           editor.selectedRange.location == stringValueWithoutSuffix.utf16.count {

            self.value = .suggestion(SuggestionViewModel(isHomePage: isHomePage, suggestion: suggestion.suggestion,
                                                         userStringValue: stringValueWithoutSuffix))
            self.selectToTheEnd(from: stringValueWithoutSuffix.count)

        } else {
            suggestionContainerViewModel?.clearSelection()
            self.value = Value(stringValue: stringValueWithoutSuffix, userTyped: true)
        }

        if stringValue.isEmpty {
            suggestionContainerViewModel?.clearUserStringValue()
            hideSuggestionWindow()
        } else {
            suggestionContainerViewModel?.setUserStringValue(stringValueWithoutSuffix,
                                                            userAppendedStringToTheEnd: isHandlingUserAppendingText)
        }

        // reset user typed flag for the next didChange event
        isHandlingUserAppendingText = false
    }

    func textView(_ textView: NSTextView, userTypedString typedString: String, at range: NSRange) {
        let userTypedLength = suggestionContainerViewModel?.userStringValue?.utf16.count ?? 0
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

        if commandSelector == #selector(NSResponder.insertTab(_:)) {
            window?.makeFirstResponder(nextKeyView)
            return false
        }

        // Collision of suffix and forward deleting
        if [#selector(NSResponder.deleteForward(_:)), #selector(NSResponder.deleteWordForward(_:))].contains(commandSelector) {
            if let currentEditor = currentEditor(),
               currentEditor.selectedRange.location == value.string.utf16.count,
               currentEditor.selectedRange.length == 0 {
                // Don't do delete when cursor is in the end
                return true
            }
        }

        if suggestionWindowController?.window?.isVisible ?? false {
            switch commandSelector {
            case #selector(NSResponder.moveDown(_:)):
                suggestionContainerViewModel?.selectNextIfPossible(); return true
            case #selector(NSResponder.moveUp(_:)):
                suggestionContainerViewModel?.selectPreviousIfPossible(); return true
            case #selector(NSResponder.deleteBackward(_:)),
                #selector(NSResponder.deleteForward(_:)),
                #selector(NSResponder.deleteToMark(_:)),
                #selector(NSResponder.deleteWordForward(_:)),
                #selector(NSResponder.deleteWordBackward(_:)),
                #selector(NSResponder.deleteToEndOfLine(_:)),
                #selector(NSResponder.deleteToEndOfParagraph(_:)),
                #selector(NSResponder.deleteToBeginningOfLine(_:)),
                #selector(NSResponder.deleteBackwardByDecomposingPreviousCharacter(_:)):
                suggestionContainerViewModel?.clearSelection(); return false
            default:
                return false
            }
        }

        return false
    }

}

extension AddressBarTextField: SuggestionViewControllerDelegate {

    func suggestionViewControllerDidConfirmSelection(_ suggestionViewController: SuggestionViewController) {
        let suggestion = suggestionContainerViewModel?.selectedSuggestionViewModel?.suggestion
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
        DispatchQueue.main.async {
            // artifacts can appear when the selection changes, especially if the size of the field has changed, this clears them
            textView.needsDisplay = true
        }
        return self.filterSuffix(fromSelectionRange: range, for: textView.string)
    }

    func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
        let textViewMenu = removingAttributeChangingMenuItems(from: menu)
        let additionalMenuItems = [
            makeAutocompleteSuggestionsMenuItem(),
            makeFullWebsiteAddressMenuItem(),
            NSMenuItem.separator()
        ]

        if let pasteMenuItemIndex = pasteMenuItemIndex(within: menu),
           let pasteAndDoMenuItem = makePasteAndDoMenuItem() {
            textViewMenu.insertItem(pasteAndDoMenuItem, at: pasteMenuItemIndex + 1)
        }

        if let insertionPoint = menuItemInsertionPoint(within: menu) {
            additionalMenuItems.reversed().forEach { item in
                textViewMenu.insertItem(item, at: insertionPoint)
            }
        } else {
            additionalMenuItems.forEach { item in
                textViewMenu.addItem(item)
            }
        }

        return textViewMenu
    }

    /// Returns the menu item after which new items should be added.
    /// This will be the first separator that comes after a predefined list of items: Cut, Copy, or Paste.
    ///
    /// - Returns: The preferred menu item. If none are found, nil is returned.
    private func menuItemInsertionPoint(within menu: NSMenu) -> Int? {
        let preferredSelectorNames = ["cut:", "copy:", "paste:"]
        var foundPreferredSelector = false

        for (index, item) in menu.items.enumerated() {
            if foundPreferredSelector && item.isSeparatorItem {
                let indexAfterSeparator = index + 1
                return menu.items.indices.contains(indexAfterSeparator) ? indexAfterSeparator : index
            }

            if let action = item.action, preferredSelectorNames.contains(action.description) {
                foundPreferredSelector = true
            }
        }

        return nil
    }

    private func pasteMenuItemIndex(within menu: NSMenu) -> Int? {
        let pasteSelector = "paste:"
        let index = menu.items.firstIndex { menuItem in
            guard let action = menuItem.action else { return false }
            return pasteSelector == action.description
        }
        return index
    }

    private static var selectorsToRemove: Set<Selector> = Set([
        Selector(("_makeLinkFromMenu:")),
        Selector(("_searchWithGoogleFromMenu:")),
        #selector(NSFontManager.orderFrontFontPanel(_:)),
        #selector(NSText.showGuessPanel(_:)),
        Selector(("replaceQuotesInSelection:")),
        #selector(NSStandardKeyBindingResponding.uppercaseWord(_:)),
        #selector(NSTextView.startSpeaking(_:)),
        #selector(NSTextView.changeLayoutOrientation(_:))
    ])

    private func removingAttributeChangingMenuItems(from menu: NSMenu) -> NSMenu {
        menu.items.reversed().forEach { menuItem in
            if let action = menuItem.action, Self.selectorsToRemove.contains(action) {
                menu.removeItem(menuItem)
            } else {
                if let submenu = menuItem.submenu, submenu.items.first(where: { submenuItem in
                    if let submenuAction = submenuItem.action, Self.selectorsToRemove.contains(submenuAction) {
                        return true
                    } else {
                        return false
                    }
                }) != nil {
                    menu.removeItem(menuItem)
                }
            }
        }
        return menu
    }

    private func makeAutocompleteSuggestionsMenuItem() -> NSMenuItem {
        let menuItem = NSMenuItem(
            title: UserText.showAutocompleteSuggestions.localizedCapitalized,
            action: #selector(toggleAutocomplete(_:)),
            keyEquivalent: ""
        )
        menuItem.state = AppearancePreferences.shared.showAutocompleteSuggestions ? .on : .off

        return menuItem
    }

    private func makeFullWebsiteAddressMenuItem() -> NSMenuItem {
        let menuItem = NSMenuItem(
            title: UserText.showFullWebsiteAddress.localizedCapitalized,
            action: #selector(toggleShowFullWebsiteAddress(_:)),
            keyEquivalent: ""
        )
        menuItem.state = AppearancePreferences.shared.showFullURL ? .on : .off

        return menuItem
    }

    private static var pasteAndGoMenuItem: NSMenuItem {
        NSMenuItem(
            title: UserText.pasteAndGo,
            action: #selector(pasteAndGo(_:)),
            keyEquivalent: ""
        )
    }

    private static var pasteAndSearchMenuItem: NSMenuItem {
        NSMenuItem(
            title: UserText.pasteAndSearch,
            action: #selector(pasteAndSearch(_:)),
            keyEquivalent: ""
        )
    }

    private func makePasteAndDoMenuItem() -> NSMenuItem? {
        if let trimmedPasteboardString = NSPasteboard.general.string(forType: .string)?.trimmingWhitespace(),
           trimmedPasteboardString.count > 0 {
            if URL(trimmedAddressBarString: trimmedPasteboardString) != nil {
                return Self.pasteAndGoMenuItem
            } else {
                return Self.pasteAndSearchMenuItem
            }
        }

        return nil
    }
}

final class AddressBarTextEditor: NSTextView {

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)

        guard let delegate = delegate as? AddressBarTextField else {
            os_log("AddressBarTextEditor: unexpected kind of delegate")
            return
        }

        if let currentSelection = selectedRanges.first as? NSRange {
            let adjustedSelection = delegate.filterSuffix(fromSelectionRange: currentSelection, for: string)
            setSelectedRange(adjustedSelection)
        }
    }

    override func paste(_ sender: Any?) {
        guard let delegate = delegate as? AddressBarTextField else {
            os_log("AddressBarTextEditor: unexpected kind of delegate")
            super.paste(sender)
            return
        }

        // Fixes an issue when url-name instead of url is pasted
        if let urlString = NSPasteboard.general.string(forType: .URL) {
            string = urlString
            delegate.handlePastedURL()
        } else {
            super.paste(sender)
        }
    }

    override func copy(_ sender: Any?) {
        CopyHandler().copy(sender)
    }

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

        delegate.textView(self, userTypedString: string, at: replacementRange.location == NSNotFound ? self.selectedRange() : replacementRange)
    }
}

final class AddressBarTextFieldCell: NSTextFieldCell {
    lazy var customEditor = AddressBarTextEditor()

    override func fieldEditor(for controlView: NSView) -> NSTextView? {
        return customEditor
    }
}

fileprivate extension NSStoryboard {
    static let suggestion = NSStoryboard(name: "Suggestion", bundle: .main)
}
