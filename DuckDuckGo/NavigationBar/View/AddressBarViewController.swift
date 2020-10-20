//
//  AddressBarViewController.swift
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
import os.log
import Combine

class AddressBarViewController: NSViewController {

    static let homeFaviconImage = NSImage(named: "HomeFavicon")
    static let webImage = NSImage(named: "Web")
    static let refreshImage = NSImage(named: "Refresh")
    static let clearImage = NSImage(named: "Clear")

    @IBOutlet weak var addressBarTextField: AddressBarTextField!
    @IBOutlet weak var passiveTextField: NSTextField!
    @IBOutlet weak var actionButton: NSButton!
    @IBOutlet weak var imageButton: NSButton!
    @IBOutlet weak var gradeButton: NSButton!
    
    private var tabCollectionViewModel: TabCollectionViewModel
    private let suggestionsViewModel = SuggestionsViewModel(suggestions: Suggestions())

    enum Mode: Equatable {
        case searching(withUrl: Bool)
        case browsing
    }
    
    private var mode: Mode = .searching(withUrl: false) {
        didSet {
            setButtons()
        }
    }

    private var selectedTabViewModelCancelable: AnyCancellable?
    private var reloadButtonCancelable: AnyCancellable?
    private var addressBarTextFieldValueCancelable: AnyCancellable?
    private var passiveAddressBarStringCancelable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("AddressBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setView(firstResponder: false)
        addressBarTextField.tabCollectionViewModel = tabCollectionViewModel
        addressBarTextField.suggestionsViewModel = suggestionsViewModel
        bindSelectedTabViewModel()
        bindAddressBarTextFieldValue()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(textFieldFirstReponderNotification(_:)),
                                               name: .firstResponder,
                                               object: nil)
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        addressBarTextField.viewDidLayout()
    }

    @IBAction func actionButtonAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        if actionButton.image === Self.refreshImage {
            selectedTabViewModel.tab.reload()
        } else {
            addressBarTextField.clearValue()
        }
    }

    private var addressBarView: AddressBarView? {
        return view as? AddressBarView
    }

    private func bindSelectedTabViewModel() {
        selectedTabViewModelCancelable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.view.window?.makeFirstResponder(self?.view.window)
            self?.bindPassiveAddressBarString()
        }
    }

    private func bindPassiveAddressBarString() {
        passiveAddressBarStringCancelable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            passiveTextField.stringValue = ""
            return
        }
        passiveAddressBarStringCancelable = selectedTabViewModel.$passiveAddressBarString.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.setPassiveTextField()
        }
    }

    private func bindAddressBarTextFieldValue() {
        addressBarTextFieldValueCancelable = addressBarTextField.$value.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateMode()
            self?.setButtons()
        }
    }

    private func setPassiveTextField() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        passiveTextField.stringValue = selectedTabViewModel.passiveAddressBarString
    }

    private func setView(firstResponder: Bool) {
        addressBarTextField.alphaValue = firstResponder ? 1 : 0
        passiveTextField.alphaValue = firstResponder ? 0 : 1

        addressBarView?.setView(stroke: firstResponder)
    }

    private func setButtons() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        let isSearchingMode = mode != .browsing
        let isURLNil = selectedTabViewModel.tab.url == nil
        let isTextFieldEditorFirstResponder = view.window?.firstResponder === addressBarTextField.currentEditor()
        let isDuckDuckGoUrl = selectedTabViewModel.tab.url?.isDuckDuckGoSearch ?? false

        gradeButton.isHidden = isSearchingMode || isTextFieldEditorFirstResponder || isDuckDuckGoUrl || isURLNil

        actionButton.isHidden = false
        if case .text(let text) = addressBarTextField.value {
            if text == "" {
                actionButton.isHidden = true
            }
        }
        actionButton.image = isSearchingMode && isTextFieldEditorFirstResponder ? Self.clearImage : Self.refreshImage

        imageButton.image = selectedTabViewModel.favicon
        if case .searching(let withUrl) = mode {
            if withUrl {
                imageButton.image = Self.webImage
            } else {
                imageButton.image = Self.homeFaviconImage
            }
        }
    }

    private func updateMode() {
        switch self.addressBarTextField.value {
        case .text: self.mode = .searching(withUrl: false)
        case .url(urlString: _, url: _, userTyped: let userTyped): self.mode = userTyped ? .searching(withUrl: true) : .browsing
        case .suggestion(let suggestionViewModel):
            switch suggestionViewModel.suggestion {
            case .phrase: self.mode = .searching(withUrl: false)
            case .website: self.mode = .searching(withUrl: true)
            case .unknown: self.mode = .searching(withUrl: false)
            }
        }
    }
    
}

extension AddressBarViewController {

    @objc func textFieldFirstReponderNotification(_ notification: Notification) {
        // NSTextField passes its first responder status down to a child view of NSTextView class
        if let textView = notification.object as? NSTextView, textView.superview?.superview === addressBarTextField {
            setView(firstResponder: true)
        } else {
            self.mode = .browsing
            setView(firstResponder: false)
        }

        setButtons()
    }
    
}
