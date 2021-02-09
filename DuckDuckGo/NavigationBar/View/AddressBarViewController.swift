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

    @IBOutlet weak var addressBarTextField: AddressBarTextField!
    @IBOutlet weak var passiveTextField: NSTextField!
    @IBOutlet weak var clearButton: NSButton!
    @IBOutlet weak var imageButton: NSButton!
    @IBOutlet weak var privacyEntryPointButton: NSButton!
    @IBOutlet var inactiveBackgroundView: NSView!
    @IBOutlet var activeBackgroundView: NSView!
    @IBOutlet var activeBackgroundViewOverHeight: NSLayoutConstraint!
    
    private var tabCollectionViewModel: TabCollectionViewModel
    private let suggestionsViewModel = SuggestionsViewModel(suggestions: Suggestions())

    enum Mode: Equatable {
        case searching(withUrl: Bool)
        case browsing
    }
    
    private var mode: Mode = .searching(withUrl: false) {
        didSet {
            updateButtons()
        }
    }

    private var selectedTabViewModelCancellable: AnyCancellable?
    private var addressBarTextFieldValueCancellable: AnyCancellable?
    private var passiveAddressBarStringCancellable: AnyCancellable?
    private var isSuggestionsVisibleCancellable: AnyCancellable?
    private var frameCancellable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("AddressBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateView(firstResponder: false)
        addressBarTextField.tabCollectionViewModel = tabCollectionViewModel
        addressBarTextField.suggestionsViewModel = suggestionsViewModel
        subscribeToSelectedTabViewModel()
        subscribeToAddressBarTextFieldValue()
        registerForMouseEnteredAndExitedEvents()
    }

    override func viewWillAppear() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(textFieldFirstReponderNotification(_:)),
                                               name: .firstResponder,
                                               object: nil)
    }

    // swiftlint:disable notification_center_detachment
    override func viewWillDisappear() {
        NotificationCenter.default.removeObserver(self)
    }
    // swiftlint:enable notification_center_detachment

    override func viewDidLayout() {
        super.viewDidLayout()

        addressBarTextField.viewDidLayout()
    }

    @IBAction func clearButtonAction(_ sender: NSButton) {
        addressBarTextField.clearValue()
    }
    
    @IBOutlet var focusRingView: ShadowView!

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.subscribeToPassiveAddressBarString()
        }
    }

    private func subscribeToPassiveAddressBarString() {
        passiveAddressBarStringCancellable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            passiveTextField.stringValue = ""
            return
        }
        passiveAddressBarStringCancellable = selectedTabViewModel.$passiveAddressBarString.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updatePassiveTextField()
        }
    }

    private func subscribeToAddressBarTextFieldValue() {
        addressBarTextFieldValueCancellable = addressBarTextField.$value.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateMode()
            self?.updateButtons()
        }
    }

    private func updatePassiveTextField() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        passiveTextField.stringValue = selectedTabViewModel.passiveAddressBarString
    }

    private func updateView(firstResponder: Bool) {
        addressBarTextField.alphaValue = firstResponder ? 1 : 0
        passiveTextField.alphaValue = firstResponder ? 0 : 1

        updateFocusRingView(firstResponder: firstResponder)
        inactiveBackgroundView.alphaValue = firstResponder ? 0 : 1
        activeBackgroundView.alphaValue = firstResponder ? 1 : 0
    }

    private func updateFocusRingView(firstResponder: Bool) {
        guard firstResponder else {
            isSuggestionsVisibleCancellable = nil
            focusRingView.removeFromSuperview()
            return
        }

        isSuggestionsVisibleCancellable = addressBarTextField.isSuggestionsWindowVisible
            .sink { [weak self] visible in
                self?.focusRingView.shadowSides = visible
                    ? [.left, .top, .right]
                    : .all
                self?.activeBackgroundViewOverHeight.isActive = visible
        }
        frameCancellable = self.view.superview?.publisher(for: \.frame).sink { [weak self] _ in
            self?.layoutFocusRingView()
        }
        view.window?.contentView?.addSubview(focusRingView)
    }

    private func layoutFocusRingView() {
        guard let superview = focusRingView.superview else { return }

        let winFrame = self.view.convert(self.view.bounds, to: nil)
        let frame = superview.convert(winFrame, from: nil)
        focusRingView.frame = frame
    }

    private func updateButtons() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        let isSearchingMode = mode != .browsing
        let isURLNil = selectedTabViewModel.tab.url == nil
        let isTextFieldFirstResponder = view.window?.firstResponder === addressBarTextField
        let isTextFieldEditorFirstResponder = view.window?.firstResponder === addressBarTextField.currentEditor()
        let isDuckDuckGoUrl = selectedTabViewModel.tab.url?.isDuckDuckGoSearch ?? false

        // Privacy entry point button
        privacyEntryPointButton.isHidden = isSearchingMode || isTextFieldFirstResponder || isDuckDuckGoUrl || isURLNil
        imageButton.isHidden = !privacyEntryPointButton.isHidden

        clearButton.isHidden = !(isTextFieldEditorFirstResponder && !addressBarTextField.value.isEmpty)

        // Image button
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
        if view.window?.firstResponder == addressBarTextField.currentEditor() {
            updateView(firstResponder: true)
        } else {
            if mode != .browsing {
                self.mode = .browsing
            }
            updateView(firstResponder: false)
        }

        updateButtons()
    }
    
}

// MARK: - Mouse states

extension AddressBarViewController {

    func registerForMouseEnteredAndExitedEvents() {
        let trackingArea = NSTrackingArea(rect: self.view.bounds, options: [.activeAlways, .mouseEnteredAndExited], owner: self, userInfo: nil)
        self.view.addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.iBeam.set()
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        super.mouseExited(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        addressBarTextField.makeMeFirstResponder()
    }

}
