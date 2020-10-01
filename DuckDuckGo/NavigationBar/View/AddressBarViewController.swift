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
    static let refreshImage = NSImage(named: "Refresh")
    static let clearImage = NSImage(named: "Clear")

    @IBOutlet weak var addressBarTextField: AddressBarTextField!
    @IBOutlet weak var passiveTextField: NSTextField!
    @IBOutlet weak var actionButton: NSButton!
    @IBOutlet weak var imageButton: NSButton!
    @IBOutlet weak var gradeButton: NSButton!
    
    private var tabCollectionViewModel: TabCollectionViewModel
    private let suggestionsViewModel = SuggestionsViewModel(suggestions: Suggestions())

    enum Mode {
        case searching
        case browsing
    }
    
    private var mode: Mode = .searching {
        didSet {
            setButtons()
        }
    }

    private var selectedTabViewModelCancelable: AnyCancellable?
    private var reloadButtonCancelable: AnyCancellable?
    private var addressBarStringCancelable: AnyCancellable?
    private var passiveAddressBarStringCancelable: AnyCancellable?
    private var suggestionsCancelable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("AddressBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setView(firstResponder: false, animated: false)
        addressBarTextField.tabCollectionViewModel = tabCollectionViewModel
        addressBarTextField.suggestionsViewModel = suggestionsViewModel
        bindSelectedTabViewModel()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(textFieldFirstReponderNotification(_:)),
                                               name: .firstResponder,
                                               object: nil)
        bindSuggestions()
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
            addressBarTextField.stringValue = ""
        }
    }

    private var addressBarView: AddressBarView? {
        return view as? AddressBarView
    }

    private func bindSelectedTabViewModel() {
        selectedTabViewModelCancelable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.view.window?.makeFirstResponder(self?.view.window)
            self?.bindAddressBarString()
            self?.bindPassiveAddressBarString()
        }
    }

    private func bindAddressBarString() {
        addressBarStringCancelable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        addressBarStringCancelable = selectedTabViewModel.$addressBarString.receive(on: DispatchQueue.main).sink { [weak self] addressBarString in
            if addressBarString.isEmpty {
                self?.mode = .searching
            } else {
                self?.mode = .browsing
            }
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

    private func bindSuggestions() {
        suggestionsCancelable = suggestionsViewModel.suggestions.$items.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.mode = .searching
        }
    }

    private func setPassiveTextField() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        passiveTextField.stringValue = selectedTabViewModel.passiveAddressBarString
    }

    private func setView(firstResponder: Bool, animated: Bool) {
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 1/3
                self.addressBarTextField.animator().alphaValue = firstResponder ? 1 : 0
                self.passiveTextField.animator().alphaValue = firstResponder ? 0 : 1
            }
        } else {
            addressBarTextField.alphaValue = firstResponder ? 1 : 0
            passiveTextField.alphaValue = firstResponder ? 0 : 1
        }

        addressBarView?.setView(stroke: firstResponder)
    }

    private func setButtons() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        let isSearchingMode = mode == .searching
        let isURLNil = selectedTabViewModel.tab.url == nil
        let isTextFieldFirstResponder = view.window?.firstResponder === addressBarTextField
        let isDuckDuckGoUrl = selectedTabViewModel.tab.url?.isDuckDuckGoSearch ?? false

        gradeButton.isHidden = isSearchingMode || isTextFieldFirstResponder || isDuckDuckGoUrl || isURLNil
        imageButton.image = isSearchingMode ? Self.homeFaviconImage : selectedTabViewModel.favicon
        actionButton.image = isSearchingMode ? Self.clearImage : Self.refreshImage
    }
    
}

extension AddressBarViewController {

    @objc func textFieldFirstReponderNotification(_ notification: Notification) {
        // NSTextField passes its first responder status down to a child view of NSTextView class
        if let textView = notification.object as? NSTextView, textView.superview?.superview === addressBarTextField {
            setView(firstResponder: true, animated: false)
        } else {
            self.mode = .browsing
            if notification.object as? WebView != nil {
                setView(firstResponder: false, animated: true)
            } else {
                setView(firstResponder: false, animated: false)
            }
        }

        setButtons()
    }
    
}
