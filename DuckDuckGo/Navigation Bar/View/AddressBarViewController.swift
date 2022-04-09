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
import Combine
import Lottie
import os.log

// swiftlint:disable type_body_length
final class AddressBarViewController: NSViewController {

    @IBOutlet weak var addressBarTextField: AddressBarTextField!
    @IBOutlet weak var passiveTextField: NSTextField!
    @IBOutlet var inactiveBackgroundView: NSView!
    @IBOutlet var activeBackgroundView: NSView!
    @IBOutlet var activeOuterBorderView: NSView!
    @IBOutlet var activeBackgroundViewWithSuggestions: NSView!
    @IBOutlet var progressIndicator: ProgressView!
    @IBOutlet var passiveTextFieldMinXConstraint: NSLayoutConstraint!

    private(set) var addressBarButtonsViewController: AddressBarButtonsViewController?

    private let tabCollectionViewModel: TabCollectionViewModel
    private let suggestionContainerViewModel: SuggestionContainerViewModel

    enum Mode: Equatable {
        case editing(isUrl: Bool)
        case browsing

        var isEditing: Bool {
            self != .browsing
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
            addressBarButtonsViewController?.isTextFieldEditorFirstResponder = isFirstResponder
        }
    }

    private var isHomePage = false {
        didSet {
            updateView()
            suggestionContainerViewModel.isHomePage = isHomePage
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private var passiveAddressBarStringCancellable: AnyCancellable?
    private var suggestionsVisibleCancellable: AnyCancellable?
    private var frameCancellable: AnyCancellable?

    private var progressCancellable: AnyCancellable?
    private var loadingCancellable: AnyCancellable?

    private var clickPoint: NSPoint?
    private var mouseDownMonitor: Any?
    private var mouseUpMonitor: Any?

    required init?(coder _: NSCoder) {
        fatalError("AddressBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel
        suggestionContainerViewModel = SuggestionContainerViewModel(
            isHomePage: tabCollectionViewModel.selectedTabViewModel?.tab.content == .homePage,
            suggestionContainer: SuggestionContainer())

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.masksToBounds = false

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
            activeOuterBorderView.isHidden = true
            activeBackgroundView.isHidden = true
            shadowView.isHidden = true
        } else {
            addressBarTextField.suggestionContainerViewModel = suggestionContainerViewModel

            registerForMouseEnteredAndExitedEvents()

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(refreshAddressBarAppearance(_:)),
                name: FireproofDomains.Constants.allowedDomainsChangedNotification,
                object: nil)

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(refreshAddressBarAppearance(_:)),
                name: NSWindow.didBecomeKeyNotification,
                object: nil)

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(refreshAddressBarAppearance(_:)),
                name: NSWindow.didResignKeyNotification,
                object: nil)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(textFieldFirstReponderNotification(_:)),
                name: .firstResponder,
                object: nil)
            addMouseMonitors()
        }
        subscribeToButtonsWidth()
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

    @IBSegueAction
    func createAddressBarButtonsViewController(_ coder: NSCoder) -> AddressBarButtonsViewController? {
        let controller = AddressBarButtonsViewController(coder: coder, tabCollectionViewModel: tabCollectionViewModel)

        addressBarButtonsViewController = controller
        controller?.delegate = self
        return addressBarButtonsViewController
    }

    @IBOutlet var shadowView: ShadowView!

    private func subscribeToSelectedTabViewModel() {
        tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.subscribeToTabContent()
            self?.subscribeToPassiveAddressBarString()
            self?.subscribeToProgressEvents()
            // don't resign first responder on tab switching
            self?.clickPoint = nil
        }.store(in: &cancellables)
    }

    private func subscribeToTabContent() {
        tabCollectionViewModel.selectedTabViewModel?.tab.$content.receive(on: DispatchQueue.main).sink { [weak self] content in
            self?.isHomePage = content == .homePage
        }.store(in: &cancellables)
    }

    private func subscribeToPassiveAddressBarString() {
        passiveAddressBarStringCancellable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            passiveTextField.stringValue = ""
            return
        }
        passiveAddressBarStringCancellable = selectedTabViewModel.$passiveAddressBarString
            .receive(on: DispatchQueue.main)
            .assign(to: \.stringValue, onWeaklyHeld: passiveTextField)
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
            guard
                selectedTabViewModel.isLoading,
                let progressIndicator = self?.progressIndicator,
                progressIndicator.isShown
            else { return }

            progressIndicator.increaseProgress(to: value)
        }

        loadingCancellable = selectedTabViewModel.$isLoading
            .sink { [weak self] isLoading in
                guard let progressIndicator = self?.progressIndicator else { return }

                if
                    isLoading,
                    selectedTabViewModel.tab.content.url?.isDuckDuckGoSearch == false {

                    progressIndicator.show(progress: selectedTabViewModel.progress, startTime: selectedTabViewModel.loadingStartTime)

                } else if progressIndicator.isShown {
                    progressIndicator.finishAndHide()
                }
            }
    }

    func subscribeToButtonsWidth() {
        addressBarButtonsViewController!.$buttonsWidth.assign(to: \.constant, onWeaklyHeld: passiveTextFieldMinXConstraint)
            .store(in: &cancellables)
    }

    private func updateView() {

        let isPassiveTextFieldHidden = isFirstResponder || mode.isEditing
        addressBarTextField.alphaValue = isPassiveTextFieldHidden ? 1 : 0
        passiveTextField.alphaValue = isPassiveTextFieldHidden ? 0 : 1

        updateShadowView(firstResponder: isFirstResponder)
        inactiveBackgroundView.alphaValue = isFirstResponder ? 0 : 1
        activeBackgroundView.alphaValue = isFirstResponder ? 1 : 0

        let isKey = view.window?.isKeyWindow ?? false
        activeOuterBorderView.alphaValue = isKey && isFirstResponder && isHomePage ? 1 : 0

        activeOuterBorderView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
        activeBackgroundView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
    }

    private func updateShadowView(firstResponder: Bool) {
        guard
            firstResponder,
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

            self?.activeOuterBorderView.isHidden = visible
            self?.activeBackgroundView.isHidden = visible
            self?.activeBackgroundViewWithSuggestions.isHidden = !visible
        }
        frameCancellable = view.superview?.publisher(for: \.frame).sink { [weak self] _ in
            self?.layoutShadowView()
        }
        view.window?.contentView?.addSubview(shadowView)
    }

    private func layoutShadowView() {
        guard let superview = shadowView.superview else { return }

        let winFrame = view.convert(view.bounds, to: nil)
        let frame = superview.convert(winFrame, from: nil)
        shadowView.frame = frame
    }

    private func updateMode(value: AddressBarTextField.Value? = nil) {
        switch value ?? addressBarTextField.value {
        case .text: mode = .editing(isUrl: false)
        case .url(urlString: _, url: _, userTyped: let userTyped): mode = userTyped ? .editing(isUrl: true) : .browsing
        case .suggestion(let suggestionViewModel):
            switch suggestionViewModel.suggestion {
            case .phrase, .unknown: mode = .editing(isUrl: false)
            case .website, .bookmark, .historyEntry: mode = .editing(isUrl: true)
            }
        }
    }

    @objc
    private func refreshAddressBarAppearance(_: Any) {
        updateMode()
        addressBarButtonsViewController?.updateButtons()

        guard let window = view.window else { return }

        NSAppearance.withAppAppearance {
            if window.isKeyWindow {
                activeBackgroundView.layer?.borderWidth = 2.0
                activeBackgroundView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
                activeBackgroundView.layer?.backgroundColor = NSColor.addressBarBackgroundColor.cgColor

                activeOuterBorderView.isHidden = !isHomePage
            } else {
                activeBackgroundView.layer?.borderWidth = 0
                activeBackgroundView.layer?.borderColor = nil
                activeBackgroundView.layer?.backgroundColor = NSColor.inactiveSearchBarBackground.cgColor

                activeOuterBorderView.isHidden = true
            }
        }
    }

}

// swiftlint:enable type_body_length

extension AddressBarViewController {

    @objc
    func textFieldFirstReponderNotification(_: Notification) {
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
        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil)
        view.addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.iBeam.set()
        super.mouseEntered(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        guard event.window === self.view.window else { return }

        let point = view.convert(event.locationInWindow, from: nil)
        let view = view.hitTest(point)

        if view?.shouldShowArrowCursor == true {
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

        mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.mouseDown(with: event)
        }
        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
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
        mouseUpMonitor = nil
        mouseDownMonitor = nil
    }

    func mouseDown(with event: NSEvent) -> NSEvent? {
        clickPoint = nil
        guard event.window === view.window else { return event }

        if let point = view.mouseLocationInsideBounds(event.locationInWindow) {
            guard
                view.window?.firstResponder !== addressBarTextField.currentEditor(),
                view.hitTest(point)?.shouldShowArrowCursor == false
            else { return event }

            // bookmark button visibility is usually determined by hover state, but we def need to hide it right now
            addressBarButtonsViewController?.bookmarkButton.isHidden = true

            // first activate app and window if needed, then make it first responder
            if view.window?.isMainWindow == true {
                addressBarTextField.makeMeFirstResponder()
                return nil
            } else {
                DispatchQueue.main.async {
                    self.addressBarTextField.makeMeFirstResponder()
                }
            }

        } else if view.window?.isMainWindow == true {
            clickPoint = event.locationInWindow
        }
        return event
    }

    func mouseUp(with event: NSEvent) -> NSEvent? {
        // click (same position down+up) outside of the field: resign first responder
        guard
            event.window === view.window,
            view.window?.firstResponder === addressBarTextField.currentEditor(),
            clickPoint == event.locationInWindow
        else { return event }

        view.window?.makeFirstResponder(nil)

        return event
    }

}

extension AddressBarViewController: AddressBarButtonsViewControllerDelegate {

    func addressBarButtonsViewControllerClearButtonClicked(_: AddressBarButtonsViewController) {
        addressBarTextField.clearValue()
    }

}

extension AddressBarViewController: AddressBarTextFieldDelegate {

    func adressBarTextField(_: AddressBarTextField, didChangeValue value: AddressBarTextField.Value) {
        updateMode(value: value)
        addressBarButtonsViewController?.textFieldValue = value
        updateView()
    }

}

extension NSView {

    fileprivate var shouldShowArrowCursor: Bool {
        self is NSButton || self is AnimationView
    }

}
