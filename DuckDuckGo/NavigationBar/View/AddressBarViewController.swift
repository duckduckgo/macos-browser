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

final class AddressBarViewController: NSViewController {

    @IBOutlet weak var addressBarTextField: AddressBarTextField!
    @IBOutlet weak var passiveTextField: NSTextField!
    @IBOutlet var inactiveBackgroundView: NSView!
    @IBOutlet var activeBackgroundView: NSView!
    @IBOutlet var activeBackgroundViewWithSuggestions: NSView!
    @IBOutlet var progressIndicator: ProgressView!

    private(set) var addressBarButtonsViewController: AddressBarButtonsViewController?
    
    private var tabCollectionViewModel: TabCollectionViewModel
    private let suggestionContainerViewModel = SuggestionContainerViewModel(suggestionContainer: SuggestionContainer())

    enum Mode: Equatable {
        case editing(isUrl: Bool)
        case browsing

        var isEditing: Bool {
            return self != .browsing
        }
    }
    
    private var mode: Mode = .editing(isUrl: false) {
        didSet {
            addressBarButtonsViewController?.controllerMode = mode
        }
    }

    private var isFirstResponder = false {
        didSet {
            updateView()
            self.addressBarButtonsViewController?.isTextFieldEditorFirstResponder = isFirstResponder
        }
    }

    private var selectedTabViewModelCancellable: AnyCancellable?
    private var passiveAddressBarStringCancellable: AnyCancellable?
    private var suggestionsVisibleCancellable: AnyCancellable?
    private var frameCancellable: AnyCancellable?

    private var progressCancellable: AnyCancellable?
    private var loadingCancellable: AnyCancellable?

    private var clickPoint: NSPoint?
    private var mouseDownMonitor: Any?
    private var mouseUpMonitor: Any?

    required init?(coder: NSCoder) {
        fatalError("AddressBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateView()
        addressBarTextField.addressBarTextFieldDelegate = self
        addressBarTextField.tabCollectionViewModel = tabCollectionViewModel
        subscribeToSelectedTabViewModel()
        registerForMouseEnteredAndExitedEvents()
    }

    override func viewWillAppear() {
        if view.window?.isPopUpWindow == true {
            addressBarTextField.isHidden = true
            inactiveBackgroundView.isHidden = true
            activeBackgroundViewWithSuggestions.isHidden = true
            activeBackgroundView.isHidden = true
            shadowView.isHidden = true
        } else {
            addressBarTextField.suggestionContainerViewModel = suggestionContainerViewModel

            registerForMouseEnteredAndExitedEvents()

            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(refreshAddressBarAppearance(_:)),
                                                   name: FireproofDomains.Constants.allowedDomainsChangedNotification,
                                                   object: nil)

            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(refreshAddressBarAppearance(_:)),
                                                   name: NSWindow.didBecomeKeyNotification,
                                                   object: nil)

            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(refreshAddressBarAppearance(_:)),
                                                   name: NSWindow.didResignKeyNotification,
                                                   object: nil)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(textFieldFirstReponderNotification(_:)),
                                                   name: .firstResponder,
                                                   object: nil)
            addMouseMonitors()
        }
    }

    // swiftlint:disable notification_center_detachment
    override func viewWillDisappear() {
        NotificationCenter.default.removeObserver(self)
        removeMouseMonitors()
    }
    // swiftlint:enable notification_center_detachment

    override func viewDidLayout() {
        super.viewDidLayout()

        addressBarTextField.viewDidLayout()
    }

    func escapeKeyDown() -> Bool {
        guard isFirstResponder else { return false }

        guard !mode.isEditing else {
            addressBarTextField.escapeKeyDown()
            return true
        }

        // If the webview doesn't have content it doesn't handle becoming the first responder properly
        if tabCollectionViewModel.selectedTabViewModel?.tab.webView.url != nil {
            tabCollectionViewModel.selectedTabViewModel?.tab.webView.makeMeFirstResponder()
        } else {
            view.superview?.becomeFirstResponder()
        }

        return true
    }

    @IBSegueAction func createAddressBarButtonsViewController(_ coder: NSCoder) -> AddressBarButtonsViewController? {
        let controller = AddressBarButtonsViewController(coder: coder, tabCollectionViewModel: tabCollectionViewModel)

        self.addressBarButtonsViewController = controller
        controller?.delegate = self
        return addressBarButtonsViewController
    }
    
    @IBOutlet var shadowView: ShadowView!

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.subscribeToPassiveAddressBarString()
            self?.subscribeToProgressEvents()
            // don't resign first responder on tab switching
            self?.clickPoint = nil
        }
    }

    private func subscribeToPassiveAddressBarString() {
        passiveAddressBarStringCancellable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            passiveTextField.stringValue = ""
            return
        }
        passiveAddressBarStringCancellable = selectedTabViewModel.$passiveAddressBarString
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.stringValue, on: passiveTextField)
    }

    private func subscribeToProgressEvents() {
        progressCancellable = nil
        loadingCancellable = nil
        
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            progressIndicator.hide(animated: false)
            return
        }

        if selectedTabViewModel.isLoading {
            progressIndicator.show(progress: selectedTabViewModel.progress, startTime: selectedTabViewModel.loadingStartTime)
        } else {
            progressIndicator.hide(animated: false)
        }

        progressCancellable = selectedTabViewModel.$progress.sink { [weak self] value in
            guard selectedTabViewModel.isLoading,
                  let progressIndicator = self?.progressIndicator,
                  progressIndicator.isShown
            else { return }

            progressIndicator.increaseProgress(to: value)
        }

        loadingCancellable = selectedTabViewModel.$isLoading
            .sink { [weak self] isLoading in
                guard let progressIndicator = self?.progressIndicator else { return }

                if isLoading,
                   selectedTabViewModel.tab.content.url?.isDuckDuckGoSearch == false {

                    progressIndicator.show(progress: selectedTabViewModel.progress, startTime: selectedTabViewModel.loadingStartTime)

                } else if progressIndicator.isShown {
                    progressIndicator.finishAndHide()
                }
        }
    }

    private func updateView() {
        let isPassiveTextFieldHidden = isFirstResponder || mode.isEditing
        addressBarTextField.alphaValue = isPassiveTextFieldHidden ? 1 : 0
        passiveTextField.alphaValue = isPassiveTextFieldHidden ? 0 : 1

        updateShadowView(firstResponder: isFirstResponder)
        inactiveBackgroundView.alphaValue = isFirstResponder ? 0 : 1
        activeBackgroundView.alphaValue = isFirstResponder ? 1 : 0
        
        activeBackgroundView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
    }

    private func updateShadowView(firstResponder: Bool) {
        guard firstResponder,
            view.window?.isPopUpWindow == false
        else {
            suggestionsVisibleCancellable = nil
            frameCancellable = nil
            shadowView.removeFromSuperview()
            return
        }

        suggestionsVisibleCancellable = addressBarTextField.suggestionWindowVisible.sink { [weak self] visible in
            self?.shadowView.shadowSides = visible ? [.left, .top, .right] : []
            self?.shadowView.shadowColor = visible ? .suggestionsShadowColor : .clear
            self?.shadowView.shadowRadius = visible ? 8.0 : 0.0
            
            self?.activeBackgroundView.isHidden = visible
            self?.activeBackgroundViewWithSuggestions.isHidden = !visible
        }
        frameCancellable = self.view.superview?.publisher(for: \.frame).sink { [weak self] _ in
            self?.layoutShadowView()
        }
        view.window?.contentView?.addSubview(shadowView)
    }

    private func layoutShadowView() {
        guard let superview = shadowView.superview else { return }

        let winFrame = self.view.convert(self.view.bounds, to: nil)
        let frame = superview.convert(winFrame, from: nil)
        shadowView.frame = frame
    }

    private func updateMode(value: AddressBarTextField.Value? = nil) {
        switch value ?? self.addressBarTextField.value {
        case .text: self.mode = .editing(isUrl: false)
        case .url(urlString: _, url: _, userTyped: let userTyped): self.mode = userTyped ? .editing(isUrl: true) : .browsing
        case .suggestion(let suggestionViewModel):
            switch suggestionViewModel.suggestion {
            case .phrase, .unknown: self.mode = .editing(isUrl: false)
            case .website, .bookmark, .historyEntry: self.mode = .editing(isUrl: true)
            }
        }
    }

    @objc private func refreshAddressBarAppearance(_ sender: Any) {
        self.updateMode()
        self.addressBarButtonsViewController?.updateButtons()

        guard let window = view.window else { return }

        NSAppearance.withAppAppearance {
            if window.isKeyWindow {
                activeBackgroundView.layer?.borderWidth = 2.0
                activeBackgroundView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
                activeBackgroundView.layer?.backgroundColor = NSColor.addressBarBackgroundColor.cgColor
            } else {
                activeBackgroundView.layer?.borderWidth = 0
                activeBackgroundView.layer?.borderColor = nil
                activeBackgroundView.layer?.backgroundColor = NSColor.inactiveSearchBarBackground.cgColor
            }
        }
    }

}

extension AddressBarViewController {

    @objc func textFieldFirstReponderNotification(_ notification: Notification) {
        if view.window?.firstResponder == addressBarTextField.currentEditor() {
            isFirstResponder = true
        } else {
            isFirstResponder = false
        }
    }
    
}

// MARK: - Mouse states

extension AddressBarViewController {

    func registerForMouseEnteredAndExitedEvents() {
        let trackingArea = NSTrackingArea(rect: self.view.bounds,
                                          options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved],
                                          owner: self,
                                          userInfo: nil)
        self.view.addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.iBeam.set()
        super.mouseEntered(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        guard event.window === self.view.window else { return }

        let point = self.view.convert(event.locationInWindow, from: nil)
        let view = self.view.hitTest(point)

        if view is NSButton {
            NSCursor.arrow.set()
        } else {
            NSCursor.iBeam.set()
        }

        super.mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
        super.mouseExited(with: event)
    }

    func addMouseMonitors() {
        guard mouseDownMonitor == nil, mouseUpMonitor == nil else { return }

        self.mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.mouseDown(with: event)
        }
        self.mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.mouseUp(with: event)
        }
    }

    func removeMouseMonitors() {
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
        self.mouseUpMonitor = nil
        self.mouseDownMonitor = nil
    }

    func mouseDown(with event: NSEvent) -> NSEvent? {
        self.clickPoint = nil
        guard event.window === self.view.window else { return event }

        if let point = self.view.mouseLocationInsideBounds(event.locationInWindow) {
            guard self.view.window?.firstResponder !== addressBarTextField.currentEditor(),
                !(self.view.hitTest(point) is NSButton)
            else { return event }

            // bookmark button visibility is usually determined by hover state, but we def need to hide it right now
            self.addressBarButtonsViewController?.bookmarkButton.isHidden = true

            // first activate app and window if needed, then make it first responder
            if self.view.window?.isMainWindow == true {
                self.addressBarTextField.makeMeFirstResponder()
                return nil
            } else {
                DispatchQueue.main.async {
                    self.addressBarTextField.makeMeFirstResponder()
                }
            }

        } else if self.view.window?.isMainWindow == true {
            self.clickPoint = event.locationInWindow
        }
        return event
    }

    func mouseUp(with event: NSEvent) -> NSEvent? {
        // click (same position down+up) outside of the field: resign first responder
        guard event.window === self.view.window,
              self.view.window?.firstResponder === addressBarTextField.currentEditor(),
              self.clickPoint == event.locationInWindow
        else { return event }

        self.view.window?.makeFirstResponder(nil)

        return event
    }

}

extension AddressBarViewController: AddressBarButtonsViewControllerDelegate {

    func addressBarButtonsViewControllerClearButtonClicked(_ addressBarButtonsViewController: AddressBarButtonsViewController) {
        addressBarTextField.clearValue()
    }

}

extension AddressBarViewController: AddressBarTextFieldDelegate {

    func adressBarTextField(_ addressBarTextField: AddressBarTextField, didChangeValue value: AddressBarTextField.Value) {
        updateMode(value: value)
        addressBarButtonsViewController?.textFieldValue = value
        updateView()
    }

}
