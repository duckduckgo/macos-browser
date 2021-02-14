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

    @IBOutlet weak var fireproofedButtonDivider: NSBox! {
        didSet {
            fireproofedButtonDivider.isHidden = true
        }
    }

    @IBOutlet weak var fireproofedButton: NSButton! {
        didSet {
            fireproofedButton.isHidden = true
            fireproofedButton.target = self
            fireproofedButton.action = #selector(fireproofedButtonAction)
        }
    }
    
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

        updateView(firstResponder: false)
        addressBarTextField.tabCollectionViewModel = tabCollectionViewModel
        addressBarTextField.suggestionsViewModel = suggestionsViewModel
        subscribeToSelectedTabViewModel()
        subscribeToAddressBarTextFieldValue()
        registerForMouseEnteredAndExitedEvents()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refreshAddressBarAppearance(_:)),
                                               name: PreserveLogins.Constants.allowedDomainsChangedNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(showUndoFireproofingPopover(_:)),
                                               name: PreserveLogins.Constants.newFireproofedDomainNotification,
                                               object: nil)
    }

    override func viewWillAppear() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(textFieldFirstReponderNotification(_:)),
                                               name: .firstResponder,
                                               object: nil)
        addMouseMonitors()
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

    @IBAction func clearButtonAction(_ sender: NSButton) {
        addressBarTextField.clearValue()
    }
    
    @IBOutlet var shadowView: ShadowView!

    private func subscribeToSelectedTabViewModel() {
        selectedTabViewModelCancellable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.subscribeToPassiveAddressBarString()
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

        updateShadowView(firstResponder: firstResponder)
        inactiveBackgroundView.alphaValue = firstResponder ? 0 : 1
        activeBackgroundView.alphaValue = firstResponder ? 1 : 0
    }

    private func updateShadowView(firstResponder: Bool) {
        guard firstResponder else {
            isSuggestionsVisibleCancellable = nil
            frameCancellable = nil
            shadowView.removeFromSuperview()
            return
        }

        isSuggestionsVisibleCancellable = addressBarTextField.isSuggestionsWindowVisible.sink { [weak self] visible in
            self?.shadowView.shadowSides = visible ? [.left, .top, .right] : .all
            self?.shadowView.shadowColor = visible ? .suggestionsShadowColor : .addressBarShadowColor
            self?.shadowView.shadowRadius = visible ? 8.0 : 4.0
            self?.activeBackgroundViewOverHeight.isActive = visible
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

    private func updateButtons() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", type: .error, className)
            return
        }

        let isSearchingMode = mode != .browsing
        let isURLNil = selectedTabViewModel.tab.url == nil
        let isTextFieldEditorFirstResponder = view.window?.firstResponder === addressBarTextField.currentEditor()
        let isDuckDuckGoUrl = selectedTabViewModel.tab.url?.isDuckDuckGoSearch ?? false

        // Privacy entry point button
        privacyEntryPointButton.isHidden = isSearchingMode || isTextFieldEditorFirstResponder || isDuckDuckGoUrl || isURLNil
        imageButton.isHidden = !privacyEntryPointButton.isHidden

        clearButton.isHidden = !(isTextFieldEditorFirstResponder && !addressBarTextField.value.isEmpty)

        // Image button
        switch mode {
        case .browsing:
            imageButton.image = selectedTabViewModel.favicon
        case .searching(withUrl: true):
            imageButton.image = Self.webImage
        case .searching(withUrl: false):
            imageButton.image = Self.homeFaviconImage
        }

        // Fireproof button
        // TODO: Put the duckduckgo.com check elsewhere
        if let url = selectedTabViewModel.tab.url, url.baseHost != "duckduckgo.com" {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.allowsImplicitAnimation = true

                fireproofedButtonDivider.isHidden = !PreserveLogins.shared.isAllowed(fireproofDomain: url.baseHost ?? "")
                fireproofedButton.isHidden = !PreserveLogins.shared.isAllowed(fireproofDomain: url.baseHost ?? "")

            }, completionHandler: nil)
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.allowsImplicitAnimation = true

                fireproofedButtonDivider.isHidden = true
                fireproofedButton.isHidden = true

            }, completionHandler: nil)
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

    @objc private func refreshAddressBarAppearance(_ sender: Any) {
        self.updateMode()
        self.updateButtons()
    }

    @objc func fireproofedButtonAction(_ sender: Any) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel, let button = sender as? NSButton else {
            return
        }

        if let host = selectedTabViewModel.tab.url?.baseHost, PreserveLogins.shared.isAllowed(fireproofDomain: host) {
            let viewController = FireproofInfoViewController.create(for: host)
            present(viewController, asPopoverRelativeTo: button.frame, of: button.superview!, preferredEdge: .minY, behavior: .transient)
        }
    }

    @objc private func showUndoFireproofingPopover(_ sender: Notification) {
        guard let domain = sender.userInfo?["domain"] as? String else { return }

        DispatchQueue.main.async {
            let viewController = UndoFireproofingViewController.create(for: domain)
            viewController.delegate = self
            let frame = self.fireproofedButton.frame.insetBy(dx: -10, dy: -10)

            self.present(viewController, asPopoverRelativeTo: frame, of: self.fireproofedButton.superview!, preferredEdge: .minY, behavior: .transient)
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

        let point = self.view.convert(event.locationInWindow, from: nil)
        if self.view.bounds.contains(point) {
            guard self.view.window?.firstResponder !== addressBarTextField.currentEditor(),
                !(self.view.hitTest(point) is NSButton)
            else { return event }

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

extension AddressBarViewController: UndoFireproofingViewControllerDelegate {

    func undoFireproofingViewController(_ viewController: UndoFireproofingViewController, requestedUndoFor domain: String) {
        PreserveLogins.shared.remove(domain: domain)
    }

}
