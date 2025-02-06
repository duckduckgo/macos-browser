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

import AppKit
import BrowserServicesKit
import Carbon.HIToolbox
import Combine
import Common
import PixelKit
import Suggestions
import Subscription
import os.log

final class AddressBarTextField: NSTextField {

    /**
     * This property controls address bar mode and influences view styling.
     *
     * If set to `false` (default), the view is styled for displaying as the regular address bar
     * in the navigation bar. If set to `true`, it's styled for displaying as a standalone view
     * on the New Tab Page.
     */
    var isSearchBox: Bool = false

    /**
     * This property keeps the preferred appearance (color scheme) of the New Tab Page.
     *
     * It's non-nil when a custom NTP background is in use. Its value is used to properly
     * style the suggestion window when it's shown.
     */
    var homePagePreferredAppearance: NSAppearance? {
        didSet {
            if suggestionWindowController != nil {
                suggestionViewController.view.appearance = homePagePreferredAppearance
            }
        }
    }

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

    private var isHomePage: Bool {
        tabCollectionViewModel.selectedTabViewModel?.tab.content == .newtab
    }

    private var isBurner: Bool {
        tabCollectionViewModel.isBurner
    }

    private var suggestionResultCancellable: AnyCancellable?
    private var selectedSuggestionViewModelCancellable: AnyCancellable?
    private var selectedTabViewModelCancellable: AnyCancellable?
    private var addressBarStringCancellable: AnyCancellable?
    private var contentTypeCancellable: AnyCancellable?

    weak var onboardingDelegate: OnboardingAddressBarReporting?

    private let searchPreferences: SearchPreferences = SearchPreferences.shared

    private enum TextDidChangeEventType {
        case none
        case userAppendingTextToTheEnd
        case userModifiedText
    }
    // flag when updating the Value from `handleTextDidChange()`
    private var currentTextDidChangeEvent: TextDidChangeEventType = .none

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()

        allowsEditingTextAttributes = true
        super.delegate = self

        registerForDraggedTypes([.string, .URL, .fileURL])
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        currentEditor()?.selectAll(self)
    }

    func viewDidLayout() {
        layoutSuggestionWindow()
    }

    // MARK: Observation

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
        selectedSuggestionViewModelCancellable = suggestionContainerViewModel?.$selectedSuggestionViewModel
            .sink { [weak self] selectedSuggestionViewModel in
                self?.displaySelectedSuggestionViewModel(selectedSuggestionViewModel)
            }
    }

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel
            .compactMap { $0 }
            .sink { [weak self] selectedTabViewModel in
                guard let self else { return }
                hideSuggestionWindow()
                subscribeToAddressBarString(selectedTabViewModel: selectedTabViewModel)
                subscribeToContentType(selectedTabViewModel: selectedTabViewModel)
            }
    }

    private func subscribeToContentType(selectedTabViewModel: TabViewModel) {
        contentTypeCancellable = selectedTabViewModel.tab.$content
            .sink { [weak self] contentType in
                self?.font = .systemFont(ofSize: contentType == .newtab ? 15 : 13)
            }
    }

    private func subscribeToAddressBarString(selectedTabViewModel: TabViewModel) {
        addressBarStringCancellable = selectedTabViewModel.$addressBarString
            .dropFirst()
            .sink { [weak self, weak selectedTabViewModel] addressBarString in
                guard let self, let selectedTabViewModel else { return }
                updateValueIfNeeded(selectedTabViewModel: selectedTabViewModel, addressBarString: addressBarString)
            }
        restoreValueIfPossible(newSelectedTabViewModel: selectedTabViewModel)
    }

    // MARK: - Value

    @Published private(set) var value: Value = .text("", userTyped: false) {
        didSet {
            guard value != oldValue else { return }

            saveUndoValue(oldValue: oldValue)
            updateAttributedStringValue()

            if let editor, case .suggestion(let suggestion) = value {
                let originalStringValue = suggestion.userStringValue
                if value.string.lowercased().hasPrefix(originalStringValue.lowercased()) {

                    editor.selectToTheEnd(from: originalStringValue.count)
                } else {
                    // if suggestion doesn't start with the user input select whole string
                    editor.selectAll(nil)
                }

            } else if let editor, editor.undoManager?.isRedoing == true {
                // also select to the end when redo action appends a suggestion as a .text Value after current selection
                let string = stringValueWithoutSuffix
                if let selectedRange = Range(editor.selectedRange(), in: string),
                   selectedRange.isEmpty,
                   selectedRange.upperBound < string.endIndex {

                    editor.selectToTheEnd(from: string.distance(from: string.startIndex, to: selectedRange.lowerBound))
                }
            }
        }
    }

    private var suffix: Suffix? {
        value.suffix
    }

    private var stringValueWithoutSuffix: String {
        let stringValue = currentEditor()?.string ?? stringValue
        guard let suffix else { return stringValue }
        return stringValue.dropping(suffix: suffix.string)
    }

    var stringValueWithoutSuffixRange: Range<String.Index> {
        let string = editor?.string ?? stringValue
        guard let suffix = suffix?.string,
              string.hasSuffix(suffix) else { return string.startIndex..<string.endIndex }
        return string.startIndex..<string.index(string.endIndex, offsetBy: -suffix.count)
    }

    private func updateAttributedStringValue() {
        withUndoDisabled {
            if let attributedString = value.toAttributedString(isHomePage: isHomePage, isBurner: isBurner) {
                self.attributedStringValue = attributedString
            } else {
                self.stringValue = value.string
            }
        }
    }

    private func saveUndoValue(oldValue: Value) {
        guard let undoManager else { return }
        // disable recording undo Value when iterating through suggestions
        if oldValue.isSuggestion && value.isSuggestion { return }
        // disable recording undo Value when updating value from `controlTextDidChange`
        // `isUndoDisabled` is set when the TextField undo record creation is disabled for current `controlTextDidChange` action
        guard currentTextDidChangeEvent == .none || isUndoDisabled else { return }

        undoManager.registerUndo(withTarget: self) { this in
            this.value = oldValue
            if let suggestion = oldValue.suggestion {
                this.suggestionContainerViewModel?.setUserStringValue(suggestion.userStringValue, userAppendedStringToTheEnd: false /* disable autocompletion */)
            }
        }
    }

    private func restoreValueIfPossible(newSelectedTabViewModel: TabViewModel) {
        // save current (possibly modified) value into the old TabViewModel when selecting another Tab
        if let oldSelectedTabViewModel = tabCollectionViewModel.selectedTabViewModel {
            guard oldSelectedTabViewModel !== newSelectedTabViewModel else {
                updateValue(selectedTabViewModel: newSelectedTabViewModel, addressBarString: nil)
                return
            }
            oldSelectedTabViewModel.lastAddressBarTextFieldValue = value
        }
        let lastAddressBarTextFieldValue = newSelectedTabViewModel.lastAddressBarTextFieldValue

        switch lastAddressBarTextFieldValue {
        case .text(let text, userTyped: let userTyped):
            if !text.isEmpty {
                restoreValue(.text(text, userTyped: userTyped))
            } else {
                updateValue(selectedTabViewModel: newSelectedTabViewModel, addressBarString: nil)
            }
        case .suggestion(let suggestionViewModel):
            let suggestion = suggestionViewModel.suggestion
            switch suggestion {
            case .website, .bookmark, .historyEntry, .internalPage, .openTab:
                restoreValue(Value(stringValue: suggestionViewModel.autocompletionString, userTyped: true))
            case .phrase(phrase: let phase):
                restoreValue(Value.text(phase, userTyped: false))
            case .unknown:
                updateValue(selectedTabViewModel: newSelectedTabViewModel, addressBarString: nil)
            }
        case .url(urlString: let urlString, url: _, userTyped: true):
            restoreValue(Value(stringValue: urlString, userTyped: true))
        case .url, .none:
            updateValue(selectedTabViewModel: newSelectedTabViewModel, addressBarString: nil)
        }
    }

    private func restoreValue(_ value: AddressBarTextField.Value) {
        self.value = value
        currentEditor()?.selectAll(self)
        clearUndoManager()
    }

    // don‘t update Value when the address bar is being edited
    private func updateValueIfNeeded(selectedTabViewModel: TabViewModel?, addressBarString: String) {
        var shouldUpdateValue: Bool {
            switch self.value {
            case .suggestion(let suggestionViewModel):
                switch suggestionViewModel.suggestion {
                case .phrase, .website, .bookmark, .historyEntry, .internalPage, .openTab: return false
                case .unknown: return true
                }
            case .text(_, userTyped: true), .url(_, _, userTyped: true): return false
            case .text, .url: return true
            }
        }
        if !self.isFirstResponder || shouldUpdateValue {
            updateValue(selectedTabViewModel: selectedTabViewModel, addressBarString: addressBarString)
        }
    }

    private func updateValue(selectedTabViewModel: TabViewModel?, addressBarString: String?) {
        guard let selectedTabViewModel = selectedTabViewModel ?? tabCollectionViewModel.selectedTabViewModel else { return }

        let addressBarString = addressBarString ?? selectedTabViewModel.addressBarString
        let isSearch = selectedTabViewModel.tab.content.userEditableUrl?.isDuckDuckGoSearch ?? false
        self.value = Value(stringValue: addressBarString, userTyped: false, isSearch: isSearch)
        clearUndoManager()
    }

    func clearValue() {
        self.value = .text("", userTyped: false)
        suggestionContainerViewModel?.clearSelection()
        suggestionContainerViewModel?.clearUserStringValue()
        hideSuggestionWindow()
        clearUndoManager()
    }

    func addressBarEnterPressed() {
        suggestionContainerViewModel?.clearUserStringValue()

        let suggestion = suggestionContainerViewModel?.selectedSuggestionViewModel?.suggestion
        navigate(suggestion: suggestion)

        hideSuggestionWindow()
    }

    private func navigate(suggestion: Suggestion?) {
        let ntpExperiment = NewTabPageSearchBoxExperiment()
        let ntpExperimentCohort: NewTabPageSearchBoxExperiment.Cohort? = ntpExperiment.isActive ? ntpExperiment.cohort : nil
        let source: NewTabPageSearchBoxExperiment.SearchSource? = {
            guard ntpExperiment.isActive else {
                return nil
            }
            let isNewTab = tabCollectionViewModel.selectedTabViewModel?.tab.content == .newtab
            guard isNewTab else {
                return .addressBar
            }
            return isSearchBox ? .ntpSearchBox : .ntpAddressBar
        }()

        switch suggestion {
        case .phrase, .none:
            if let source {
                ntpExperiment.recordSearch(from: source)
            }
        default:
            break
        }

        let autocompletePixel: GeneralPixel? = {
            switch suggestion {
            case .phrase:
                return .autocompleteClickPhrase(from: source, cohort: ntpExperimentCohort, onboardingCohort: ntpExperiment.onboardingCohort)
            case .website:
                return .autocompleteClickWebsite(from: source, cohort: ntpExperimentCohort, onboardingCohort: ntpExperiment.onboardingCohort)
            case .bookmark(_, _, let isFavorite, _):
                if isFavorite {
                    return .autocompleteClickFavorite(from: source, cohort: ntpExperimentCohort, onboardingCohort: ntpExperiment.onboardingCohort)
                } else {
                    return .autocompleteClickBookmark(from: source, cohort: ntpExperimentCohort, onboardingCohort: ntpExperiment.onboardingCohort)
                }
            case .historyEntry:
                return .autocompleteClickHistory(from: source, cohort: ntpExperimentCohort, onboardingCohort: ntpExperiment.onboardingCohort)
            case .openTab:
                return .autocompleteClickOpenTab(from: source, cohort: ntpExperimentCohort, onboardingCohort: ntpExperiment.onboardingCohort)
            default:
                return nil
            }
        }()

        if let autocompletePixel {
            PixelKit.fire(autocompletePixel)
        }

        if case .internalPage(title: let title, url: let url) = suggestion,
           url == .bookmarks || url.isSettingsURL {
            // when choosing an internal page suggestion prefer already open tab
            switchTo(OpenTab(title: title, url: url))
        } else if case .openTab(let title, url: let url) = suggestion {
            switchTo(OpenTab(title: title, url: url))
        } else if NSApp.isCommandPressed {
            openNew(NSApp.isOptionPressed ? .window : .tab, selected: NSApp.isShiftPressed, suggestion: suggestion)
        } else {
            hideSuggestionWindow()
            updateTabUrl(suggestion: suggestion, downloadRequested: NSApp.isOptionPressed && !NSApp.isShiftPressed)
        }

        currentEditor()?.selectAll(self)
    }

    func escapeKeyDown() {
        if isSuggestionWindowVisible {
            hideSuggestionWindow()
            return
        }

        // reset to actual value
        let oldValue = value
        clearValue()
        updateValue(selectedTabViewModel: nil, addressBarString: nil)

        if oldValue == value {
            // resign first responder if nothing has changed
            self.window?.makeFirstResponder(nil)
        }
    }

    private func updateTabUrlWithUrl(_ providedUrl: URL, userEnteredValue: String, downloadRequested: Bool, suggestion: Suggestion?) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            Logger.general.error("AddressBarTextField: Selected tab view model is nil")
            return
        }

#if APPSTORE
        if providedUrl.isFileURL, !providedUrl.isWritableLocation(), // is sandbox extension available for the file?
           let window = self.window {

            NSAlert.cannotOpenFileAlert().beginSheetModal(for: window) { response in
                switch response {
                case .alertSecondButtonReturn:
                    WindowControllersManager.shared.show(url: URL.ddgLearnMore, source: .ui, newTab: false)
                    return
                default:
                    window.makeFirstResponder(self)
                    return
                }
            }
            return
        }
#endif

        // Prevent typing in subscription URLs directly in the address bar
        let baseURL = Application.appDelegate.subscriptionManager.url(for: .baseURL)
        let identityTheftRestorationURL = Application.appDelegate.subscriptionManager.url(for: .identityTheftRestoration)
        if providedUrl.isChild(of: baseURL) || providedUrl.isChild(of: identityTheftRestorationURL) {
            self.updateValue(selectedTabViewModel: nil, addressBarString: nil) // reset
            self.window?.makeFirstResponder(nil)
            return
        }

        self.window?.makeFirstResponder(nil)
        selectedTabViewModel.tab.setUrl(providedUrl, source: .userEntered(userEnteredValue, downloadRequested: downloadRequested))
        if downloadRequested {
            updateValue(selectedTabViewModel: nil, addressBarString: nil)
        }
    }

    private func updateTabUrl(suggestion: Suggestion?, downloadRequested: Bool) {
        makeUrl(suggestion: suggestion,
                stringValueWithoutSuffix: stringValueWithoutSuffix,
                completion: { [weak self] url, userEnteredValue, isUpgraded in
            guard let url = url else { return }

            if isUpgraded {
                self?.updateTab(self?.tabCollectionViewModel.selectedTabViewModel?.tab, upgradedTo: url)
            }
            self?.updateTabUrlWithUrl(url, userEnteredValue: userEnteredValue, downloadRequested: downloadRequested, suggestion: suggestion)
        })
    }

    private func updateTab(_ tab: Tab?, upgradedTo url: URL?) {
        guard let tab, let url else { return }
        tab.setMainFrameConnectionUpgradedTo(url)
    }

    enum TabOrWindow { case tab, window }
    private func openNew(_ tabOrWindow: TabOrWindow, selected: Bool, suggestion: Suggestion?) {
        makeUrl(suggestion: suggestion,
                stringValueWithoutSuffix: stringValueWithoutSuffix) { [weak self] url, userEnteredValue, isUpgraded in
            guard let self, let url else {
                Logger.general.error("AddressBarTextField: Making url from address bar string failed")
                return
            }
            let tab = Tab(content: .url(url, source: .userEntered(userEnteredValue)),
                          shouldLoadInBackground: true,
                          burnerMode: tabCollectionViewModel.burnerMode)

            if isUpgraded {
                updateTab(tab, upgradedTo: url)
            }

            if selected {
                // reset address bar value
                updateValue(selectedTabViewModel: nil, addressBarString: nil)
                window?.makeFirstResponder(nil)
            }
            switch tabOrWindow {
            case .tab:
                tabCollectionViewModel.append(tab: tab, selected: selected)
            case .window:
                WindowsManager.openNewWindow(with: tab, showWindow: selected, popUp: false)
            }
        }
    }

    private func switchTo(_ tab: OpenTab) {
        // reset value so it‘s not restored next time we come back to the tab
        value = .text("", userTyped: false)
        WindowControllersManager.shared.show(url: tab.url, source: .switchToOpenTab, newTab: true /* in case not found */)
    }

    private func makeUrl(suggestion: Suggestion?, stringValueWithoutSuffix: String, completion: @escaping (URL?, String, Bool) -> Void) {
        let finalUrl: URL?
        let userEnteredValue: String
        switch suggestion {
        case .bookmark(title: _, url: let url, isFavorite: _, allowedInTopHits: _),
             .historyEntry(title: _, url: let url, allowedInTopHits: _),
             .website(url: let url),
             .internalPage(title: _, url: let url),
             .openTab(title: _, url: let url):
            finalUrl = url
            userEnteredValue = url.absoluteString
        case .phrase(phrase: let phrase),
             .unknown(value: let phrase):
            finalUrl = URL.makeSearchUrl(from: phrase)
            userEnteredValue = phrase
        case .none:
            finalUrl = URL.makeURL(from: stringValueWithoutSuffix)
            userEnteredValue = stringValueWithoutSuffix
        }

        guard let url = finalUrl else {
            completion(finalUrl, userEnteredValue, false)
            return
        }

        upgradeToHttps(url: url, userEnteredValue: userEnteredValue, completion: completion)
    }

    private func upgradeToHttps(url: URL, userEnteredValue: String, completion: @escaping (URL?, String, Bool) -> Void) {
        Task {
            let result = await PrivacyFeatures.httpsUpgrade.upgrade(url: url)
            switch result {
            case let .success(upgradedUrl):
                completion(upgradedUrl, userEnteredValue, true)
            case .failure:
                completion(url, userEnteredValue, false)
            }
        }
    }

    // MARK: - Undo Manager

    func undoManager(for view: NSTextView) -> UndoManager? {
        undoManager
    }

    func clearUndoManager() {
        undoManager?.removeAllActions()
    }

    /// flag is set when the TextField undo record creation is disabled for current `controlTextDidChange` action
    /// AddressBarTextEditor checks the flag and disables UndoManager while it‘s set to prevent doubling Undo action for both text change and direct Value setting
    private(set) var isUndoDisabled = false

    func withUndoDisabled<R>(do job: () -> R) -> R {
        isUndoDisabled = true
        defer {
            isUndoDisabled = false
        }
        return job()
    }

    // MARK: - Suggestion window

    private func displaySelectedSuggestionViewModel(_ selectedSuggestionViewModel: SuggestionViewModel?) {
        guard let suggestionWindow = suggestionWindowController?.window else {
            Logger.general.error("AddressBarTextField: Window not available")
            return
        }

        if !suggestionWindow.isVisible && selectedSuggestionViewModel == nil { return }

        guard let selectedSuggestionViewModel else {
            if let originalStringValue = suggestionContainerViewModel?.userStringValue {
                self.value = Value(stringValue: originalStringValue, userTyped: true)
            } else {
                clearValue()
            }

            return
        }

        self.value = Value.suggestion(selectedSuggestionViewModel)
    }

    enum SuggestionWindowSizes {
        static let padding = CGPoint(x: -20, y: 1)
    }

    @objc dynamic private var suggestionWindowController: NSWindowController?
    private(set) lazy var suggestionViewController: SuggestionViewController = {
        NSStoryboard.suggestion.instantiateController(identifier: "SuggestionViewController") { coder in
            let suggestionViewController = SuggestionViewController(coder: coder,
                                                                    suggestionContainerViewModel: self.suggestionContainerViewModel!,
                                                                    isBurner: self.isBurner)
            suggestionViewController?.delegate = self
            return suggestionViewController
        }
    }()

    var isSuggestionWindowVisiblePublisher: AnyPublisher<Bool, Never> {
        self.publisher(for: \.suggestionWindowController?.window?.isVisible)
            .map { $0 ?? false }
            .eraseToAnyPublisher()
    }

    var isSuggestionWindowVisible: Bool {
        suggestionWindowController?.window?.isVisible == true
    }

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
            Logger.general.error("AddressBarTextField: Window not available")
            return
        }

        if isSearchBox {
            suggestionViewController.innerBorderViewTopConstraint.constant = 0
            suggestionViewController.innerBorderViewBottomConstraint.constant = 0
            suggestionViewController.innerBorderViewLeadingConstraint.constant = 0
            suggestionViewController.innerBorderViewTrailingConstraint.constant = 0
            suggestionViewController.backgroundView.borderWidth = 0

            suggestionViewController.view.appearance = homePagePreferredAppearance
            suggestionViewController.view.effectiveAppearance.performAsCurrentDrawingAppearance {
                suggestionViewController.backgroundView.backgroundColor = .homePageAddressBarBackground
                suggestionViewController.innerBorderView.borderColor = .homePageAddressBarBorder
            }
        }

        guard !suggestionWindow.isVisible, isFirstResponder else { return }

        window.addChildWindow(suggestionWindow, ordered: .above)
        layoutSuggestionWindow()
        postSuggestionWindowOpenNotification()
    }

    private func postSuggestionWindowOpenNotification() {
        NotificationCenter.default.post(name: .suggestionWindowOpen, object: nil)
    }

    func hideSuggestionWindow() {
        guard let suggestionWindow = suggestionWindowController?.window, suggestionWindow.isVisible,
              let parent = suggestionWindow.parent else { return }

        parent.removeChildWindow(suggestionWindow)
        suggestionWindow.orderOut(nil)
    }

    private func layoutSuggestionWindow() {
        guard let window = window, let suggestionWindow = suggestionWindowController?.window else {
            return
        }
        guard let superview = superview else {
            Logger.general.error("AddressBarTextField: Superview not available")
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

    @objc func pasteAndGo(_ menuItem: NSMenuItem) {
        guard let pasteboardString = NSPasteboard.general.string(forType: .string)?.trimmingWhitespace(),
              let url = URL(trimmedAddressBarString: pasteboardString) else {
            assertionFailure("Pasteboard doesn't contain URL")
            return
        }

        tabCollectionViewModel.selectedTabViewModel?.tab.setUrl(url, source: .userEntered(pasteboardString))
    }

    @objc func pasteAndSearch(_ menuItem: NSMenuItem) {
        guard let pasteboardString = NSPasteboard.general.string(forType: .string)?.trimmingWhitespace(),
              let searchURL = URL.makeSearchUrl(from: pasteboardString) else {
            assertionFailure("Can't create search URL from pasteboard string")
            return
        }

        tabCollectionViewModel.selectedTabViewModel?.tab.setUrl(searchURL, source: .userEntered(pasteboardString))
    }

    @objc func toggleAutocomplete(_ menuItem: NSMenuItem) {
        searchPreferences.showAutocompleteSuggestions.toggle()

        let shouldShowAutocomplete = searchPreferences.showAutocompleteSuggestions

        menuItem.state = shouldShowAutocomplete ? .on : .off

        if shouldShowAutocomplete {
            handleTextDidChange()
        } else {
            hideSuggestionWindow()
        }
    }

    @objc func toggleShowFullWebsiteAddress(_ menuItem: NSMenuItem) {
        AppearancePreferences.shared.showFullURL.toggle()

        let shouldShowFullURL = AppearancePreferences.shared.showFullURL
        menuItem.state = shouldShowFullURL ? .on : .off
    }

}

// MARK: - NSDraggingDestination
extension AddressBarTextField {

    override func draggingEntered(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func draggingUpdated(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool {
        if let url = draggingInfo.draggingPasteboard.url {
            tabCollectionViewModel.selectedTabViewModel?.tab.setUrl(url, source: .userEntered(draggingInfo.draggingPasteboard.string(forType: .string) ?? url.absoluteString))

        } else if let stringValue = draggingInfo.draggingPasteboard.string(forType: .string) {
            self.value = .init(stringValue: stringValue, userTyped: false)
            clearUndoManager()

            window?.makeKeyAndOrderFront(self)
            NSApp.activate(ignoringOtherApps: true)
            self.makeMeFirstResponder()

        } else {
            return false
        }

        return true
    }

}

extension AddressBarTextField {

    enum Value: Equatable {
        case text(_ text: String, userTyped: Bool)
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
                self = .text(stringValue, userTyped: userTyped)
            }
        }

        var string: String {
            switch self {
            case .text(let text, _):
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

        var suffix: Suffix? {
            Suffix(value: self)
        }

        var isEmpty: Bool {
            switch self {
            case .text(let text, _):
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

        var suggestion: SuggestionViewModel? {
            if case .suggestion(let suggestion) = self {
                return suggestion
            }
            return nil
        }

        var isSuggestion: Bool {
            self.suggestion != nil
        }

        func toAttributedString(isHomePage: Bool, isBurner: Bool) -> NSAttributedString? {
            var attributes: [NSAttributedString.Key: Any] {
                let size: CGFloat = isHomePage ? 15 : 13
                return [
                    .font: NSFont.systemFont(ofSize: size, weight: .regular),
                    .foregroundColor: NSColor.textColor,
                    .kern: -0.16
                ]
            }

            guard let suffix else { return nil }

            let attributedString = NSMutableAttributedString(string: self.string, attributes: attributes)
            attributedString.append(suffix.toAttributedString(size: isHomePage ? 15 : 13, isBurner: isBurner))

            return attributedString
        }

    }

    enum Suffix {
        init?(value: Value) {
            if case .text("", _) = value {
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
                 .historyEntry(title: _, url: let url, allowedInTopHits: _),
                 .internalPage(title: _, url: let url):
                if let title = suggestionViewModel.title,
                   !title.isEmpty,
                   suggestionViewModel.autocompletionString != title {
                    self = .title(title)
                } else if let host = url.root?.toString(decodePunycode: true, dropScheme: true, dropTrailingSlash: true) {
                    self = .visit(host: host)
                } else {
                    self = .url(url)
                }
            case .openTab(title: _, url: let url):
                self = .openTab(url)
            case .unknown:
                self = Suffix.search
            }
        }

        case search
        case visit(host: String)
        case url(URL)
        case title(String)
        case openTab(URL)

        func toAttributedString(size: CGFloat, isBurner: Bool) -> NSAttributedString {
            let suffixColor = isBurner ? NSColor.burnerAccent : NSColor.addressBarSuffix
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: size, weight: .light),
                .foregroundColor: suffixColor
            ]
            return NSAttributedString(string: string, attributes: attrs)
        }

        static let searchSuffix = " – \(UserText.searchDuckDuckGoSuffix)"
        static let searchOpenTabSuffix = " – \(UserText.duckDuckGoSearchSuffix)"
        static let internalPageOpenTabSuffix = " – \(UserText.duckDuckGo)"
        static let visitSuffix = " – \(UserText.addressBarVisitSuffix)"

        var string: String {
            switch self {
            case .search:
                return Self.searchSuffix
            case .visit(host: let host):
                return "\(Self.visitSuffix) \(host)"
            case .openTab(let url) where url.isDuckDuckGoSearch:
                return Self.searchOpenTabSuffix
            case .openTab(let url) where url.isDuckURLScheme:
                return Self.internalPageOpenTabSuffix
            case .url(let url) where url.isDuckDuckGoSearch:
                return Self.searchSuffix
            case .url(let url), .openTab(let url):
                return " – " + url.toString(decodePunycode: false,
                                            dropScheme: true,
                                            dropTrailingSlash: false)
            case .title(let title):
                return " – " + title
            }
        }
    }

}
extension AddressBarTextField.Value? {
    var isEmpty: Bool {
        self?.isEmpty ?? true
    }
}

// MARK: - NSTextFieldDelegate
extension AddressBarTextField: NSTextFieldDelegate {

    func controlTextDidEndEditing(_ obj: Notification) {
        suggestionContainerViewModel?.clearUserStringValue()
        hideSuggestionWindow()
    }

    func controlTextDidChange(_ obj: Notification) {
        handleTextDidChange()
        onboardingDelegate?.trackAddressBarTypedIn()
    }

    private func handleTextDidChange() {
        let stringValueWithoutSuffix = self.stringValueWithoutSuffix
        self.currentTextDidChangeEvent = (currentTextDidChangeEvent != .none) ? currentTextDidChangeEvent : .userModifiedText
        defer {
            self.currentTextDidChangeEvent = .none
        }

        if stringValue.isEmpty {
            suggestionContainerViewModel?.clearUserStringValue()
            hideSuggestionWindow()
        } else {
            suggestionContainerViewModel?.setUserStringValue(stringValueWithoutSuffix, userAppendedStringToTheEnd: currentTextDidChangeEvent == .userAppendingTextToTheEnd)
        }

        // if user continues typing letters from displayed Suggestion
        // don't blink and keep the Suggestion displayed
        if case .userAppendingTextToTheEnd = currentTextDidChangeEvent,
           let suggestion = autocompleteSuggestionBeingTypedOverByUser(with: stringValueWithoutSuffix) {
            self.value = .suggestion(SuggestionViewModel(isHomePage: isHomePage, suggestion: suggestion.suggestion, userStringValue: stringValueWithoutSuffix))

        } else {
            suggestionContainerViewModel?.clearSelection()
            self.value = Value(stringValue: stringValueWithoutSuffix, userTyped: true)
        }
    }

    private func autocompleteSuggestionBeingTypedOverByUser(with newUserEnteredValue: String) -> SuggestionViewModel? {
        if case .userAppendingTextToTheEnd = currentTextDidChangeEvent, // only when typing over
           case .suggestion(let suggestion) = self.value, // current value should be an autocompletion suggestion
           !newUserEnteredValue.contains(" "), // disable autocompletion when user entered Space
           newUserEnteredValue.hasPrefix(suggestion.userStringValue), // newly typed value should start with a previous value
           suggestion.autocompletionString.hasPrefix(newUserEnteredValue) { // new typed value should still match the selected suggestion

            return suggestion
        }
        return nil
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline)
           || commandSelector == #selector(insertNewlineIgnoringFieldEditor)
           || commandSelector == Selector(("noop:")) && NSApp.isReturnOrEnterPressed {
            self.addressBarEnterPressed()
            return true
        } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
            window?.makeFirstResponder(nextKeyView)
            return false

        } else if commandSelector == Selector(("noop:")),
                  let event = NSApp.currentEvent,
                  case .keyDown = event.type,
                  event.keyCode == kVK_ForwardDelete,
                  event.modifierFlags.contains(.command) {
            // Cmd + Forward Delete
            if isSuggestionWindowVisible {
                suggestionContainerViewModel?.clearSelection()
            }

            textView.deleteToEndOfLine(control)
            return true
        }

        if isSuggestionWindowVisible {
            switch commandSelector {
            case #selector(NSResponder.moveDown(_:)):
                suggestionContainerViewModel?.selectNextIfPossible()
                return true

            case #selector(NSResponder.moveUp(_:)):
                suggestionContainerViewModel?.selectPreviousIfPossible()
                return true

            default:
                return false
            }
        }

        return false
    }

}

// MARK: - NSTextViewDelegate
extension AddressBarTextField: NSTextViewDelegate {

    func textView(_ textView: NSTextView, userTypedString typedString: String, at insertionNsRange: NSRange, callback: () -> Void) {
        let oldValue = stringValueWithoutSuffix
        let insertionRange = Range(insertionNsRange, in: oldValue) ?? oldValue.startIndex..<oldValue.endIndex

        let selectionStart = min(oldValue.index(oldValue.startIndex,
                                                // selected area starts from the user-typed value end and goes to the end of the autocomplete suggestion
                                                offsetBy: min(suggestionContainerViewModel?.userStringValue?.count ?? 0, oldValue.count)),
                                 oldValue.endIndex)
        let selectionEnd = oldValue.endIndex

        // this range should match editor selection range when user is overtyping currently displayed suggestion
        let selectedSuggestionRange = selectionStart..<selectionEnd

        // if user types over selected autocomplete suggestion or appends to the end of string or replaces the whole string
        if insertionRange.upperBound >= oldValue.endIndex {
            // we'll select the first suggested item or update userEnteredText in currently selected suggestion
            currentTextDidChangeEvent = .userAppendingTextToTheEnd
        } else {
            currentTextDidChangeEvent = .userModifiedText
        }

        // when typing over the autocomplete suggestion
        if insertionRange == selectedSuggestionRange,
           autocompleteSuggestionBeingTypedOverByUser(with: oldValue.replacingCharacters(in: selectedSuggestionRange, with: typedString)) != nil {
            // disable TextEditor‘s built-in undo, we‘ll save the Suggestion Value to the Undo Manager instead
            isUndoDisabled = true
        }

        // call `AddressBarTextEditor:super.insertText(typedString, replacementRange: insertionRange)`
        // which will call `controlTextDidChange:` with `isHandlingUserAppendingText`/`isUndoDisabled` flags set if suited
        callback()

        currentTextDidChangeEvent = .none
        isUndoDisabled = false
    }

    func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange _: NSRange, toCharacterRange range: NSRange) -> NSRange {
        DispatchQueue.main.async {
            // artifacts can appear when the selection changes, especially if the size of the field has changed, this clears them
            textView.needsDisplay = true
        }
        guard let range = Range(range, in: textView.string) else { return range }
        return NSRange(range.clamped(to: stringValueWithoutSuffixRange), in: textView.string)
    }

    func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
        removeUnwantedMenuItems(from: menu)

        if let pasteAndGoMenuItem = NSMenuItem.makePasteAndGoMenuItem() {
            let pasteMenuItemIndex = menu.indexOfItem(withTarget: nil, andAction: #selector(NSText.paste)) // ?? -1
            menu.insertItem(pasteAndGoMenuItem, at: pasteMenuItemIndex + 1)
        }

        if let sharingMenuItem = menu.item(with: Self.shareMenuItemAction) {
            sharingMenuItem.title = UserText.shareMenuItem
            sharingMenuItem.submenu = SharingMenu(title: UserText.shareMenuItem)
        }

        let additionalMenuItems: [NSMenuItem] = [
            .toggleAutocompleteSuggestionsMenuItem,
            .toggleFullWebsiteAddressMenuItem,
            .separator()
        ]
        let insertionPoint = menuItemInsertionPoint(within: menu)
        for (idx, item) in additionalMenuItems.enumerated() {
            menu.insertItem(item, at: insertionPoint + idx)
        }

        return menu
    }

    /// Returns the menu item after which new items should be added.
    /// This will be the first separator that comes after a predefined list of items: Cut, Copy, or Paste.
    ///
    /// - Returns: The preferred menu item. If none are found, nil is returned.
    private func menuItemInsertionPoint(within menu: NSMenu) -> Int {
        let cutItemIndex = max(0, menu.indexOfItem(withTarget: nil, andAction: #selector(NSText.cut)) /* ?? -1 */)
        let separatorIndex = menu.items[cutItemIndex...].firstIndex(where: { $0.isSeparatorItem })

        if let separatorIndex {
            return separatorIndex + 1
        }
        return menu.numberOfItems
    }

    private static var selectorsToRemove = Set([
        Selector(("_openLinkFromMenu:")),
        NSSelectorFromString("invoke"),
        Selector(("_openPreview")),
        Selector(("runActionForDictionary:")),
        Selector(("_makeLinkFromMenu:")),
        Selector(("_searchWithGoogleFromMenu:")),
        #selector(NSFontManager.orderFrontFontPanel(_:)),
        #selector(NSText.showGuessPanel(_:)),
        Selector(("replaceQuotesInSelection:")),
        #selector(NSStandardKeyBindingResponding.uppercaseWord(_:)),
        #selector(NSTextView.startSpeaking(_:)),
        #selector(NSTextView.changeLayoutOrientation(_:)),
        #selector(NSTextView.orderFrontSubstitutionsPanel(_:))
    ])
    private static let shareMenuItemAction = Selector(("_performStandardShareMenuItem:"))

    private func removeUnwantedMenuItems(from menu: NSMenu) {
        // filter out menu items with action from `selectorsToRemove` or containing submenu items with action from the list
        menu.items = menu.items.filter { menuItem in
            menuItem.action.map { action in  Self.selectorsToRemove.contains(action) } != true
            && Self.selectorsToRemove.isDisjoint(with: menuItem.submenu?.items.compactMap(\.action) ?? [])
        }
    }

}

private extension NSMenuItem {

    static var toggleAutocompleteSuggestionsMenuItem: NSMenuItem {
        let menuItem = NSMenuItem(
            title: UserText.showAutocompleteSuggestions.localizedCapitalized,
            action: #selector(AddressBarTextField.toggleAutocomplete(_:)),
            keyEquivalent: ""
        )
        menuItem.state = SearchPreferences.shared.showAutocompleteSuggestions ? .on : .off

        return menuItem
    }

    static var toggleFullWebsiteAddressMenuItem: NSMenuItem {
        let menuItem = NSMenuItem(
            title: UserText.showFullWebsiteAddress.localizedCapitalized,
            action: #selector(AddressBarTextField.toggleShowFullWebsiteAddress(_:)),
            keyEquivalent: ""
        )
        menuItem.state = AppearancePreferences.shared.showFullURL ? .on : .off

        return menuItem
    }

    private static var pasteAndGoMenuItem: NSMenuItem {
        NSMenuItem(
            title: UserText.pasteAndGo,
            action: #selector(AddressBarTextField.pasteAndGo(_:)),
            keyEquivalent: ""
        )
    }

    private static var pasteAndSearchMenuItem: NSMenuItem {
        NSMenuItem(
            title: UserText.pasteAndSearch,
            action: #selector(AddressBarTextField.pasteAndSearch(_:)),
            keyEquivalent: ""
        )
    }

    static func makePasteAndGoMenuItem() -> NSMenuItem? {
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

// MARK: - SuggestionViewControllerDelegate
extension AddressBarTextField: SuggestionViewControllerDelegate {

    func suggestionViewControllerDidConfirmSelection(_ suggestionViewController: SuggestionViewController) {
        let suggestion = suggestionContainerViewModel?.selectedSuggestionViewModel?.suggestion
        navigate(suggestion: suggestion)
    }

}

extension Notification.Name {
    static let suggestionWindowOpen = Notification.Name("suggestionWindowOpen")
}

fileprivate extension NSStoryboard {
    static let suggestion = NSStoryboard(name: "Suggestion", bundle: .main)
}
