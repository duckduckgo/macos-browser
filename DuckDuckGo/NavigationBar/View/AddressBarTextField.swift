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

class AddressBarTextField: NSTextField {

    var tabCollectionViewModel: TabCollectionViewModel! {
        didSet {
            bindSelectedTabViewModel()
        }
    }

    private let suggestionsViewModel = SuggestionsViewModel(suggestions: Suggestions())

    private var originalStringValue: String?

    private var selectedSuggestionViewModelCancellable: AnyCancellable?
    private var selectedTabViewModelCancelable: AnyCancellable?
    private var searchSuggestionsCancelable: AnyCancellable?
    private var addressBarStringCancelable: AnyCancellable?

    override func awakeFromNib() {
        super.awakeFromNib()

        super.delegate = self
        initSuggestionsWindow()
        bindSelectedSuggestionViewModel()
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        currentEditor()?.selectAll(self)
    }

    func viewDidLayout() {
        layoutSuggestionWindow()
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
            stringValue = ""
            return
        }
        addressBarStringCancelable = selectedTabViewModel.$addressBarString.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.setStringValue()
        }
    }
    private func setStringValue() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }
        let addressBarString = selectedTabViewModel.addressBarString
        stringValue = addressBarString
        if addressBarString == "" {
            makeMeFirstResponder()
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

    private func confirmStringValue() {
        hideSuggestionsWindow()
        setUrl()
    }

    private func setUrl() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }
        guard let url = URL.makeURL(from: stringValue) else {
            os_log("%s: Making url from address bar string failed", log: OSLog.Category.general, type: .error, className)
            return
        }
        selectedTabViewModel.tab.url = url
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
            os_log("AddressBarTextField: Window not available", log: OSLog.Category.general, type: .error)
            return
        }

        if suggestionsWindow.isVisible { return }

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

        let padding = CGFloat(3)
        suggestionsWindow.setFrame(NSRect(x: 0, y: 0, width: superview.frame.width + 2 * padding, height: 0), display: true)

        var point = superview.bounds.origin
        point.x -= padding

        let converted = superview.convert(point, to: nil)
        let screen = window.convertPoint(toScreen: converted)
        suggestionsWindow.setFrameTopLeftPoint(screen)
    }
}

extension AddressBarTextField: NSSearchFieldDelegate {

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

extension AddressBarTextField: SuggestionsViewControllerDelegate {

    func suggestionsViewControllerDidConfirmSelection(_ suggestionsViewController: SuggestionsViewController) {
        confirmStringValue()
    }

}
