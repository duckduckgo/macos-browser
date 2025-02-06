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

final class AddressBarViewController: NSViewController, ObservableObject {

    @IBOutlet var addressBarTextField: AddressBarTextField!
    @IBOutlet var passiveTextField: NSTextField!
    @IBOutlet var inactiveBackgroundView: NSView!
    @IBOutlet var activeBackgroundView: ColorView!
    @IBOutlet var activeOuterBorderView: ColorView!
    @IBOutlet var activeBackgroundViewWithSuggestions: ColorView!
    @IBOutlet var innerBorderView: ColorView!
    @IBOutlet var progressIndicator: LoadingProgressView!
    @IBOutlet var passiveTextFieldMinXConstraint: NSLayoutConstraint!
    @IBOutlet var activeTextFieldMinXConstraint: NSLayoutConstraint!
    @IBOutlet var buttonsContainerView: NSView!
    @IBOutlet var switchToTabBox: ColorView!
    @IBOutlet var switchToTabLabel: NSTextField!
    @IBOutlet var switchToTabBoxMinXConstraint: NSLayoutConstraint!
    private static let defaultActiveTextFieldMinX: CGFloat = 40

    private let popovers: NavigationBarPopovers?
    var addressBarButtonsViewController: AddressBarButtonsViewController?

    private let tabCollectionViewModel: TabCollectionViewModel
    private var tabViewModel: TabViewModel?
    private let suggestionContainerViewModel: SuggestionContainerViewModel
    private let isBurner: Bool
    private let onboardingPixelReporter: OnboardingAddressBarReporting
    let isSearchBox: Bool

    enum Mode: Equatable {
        enum EditingMode {
            case text
            case url
            case openTabSuggestion
        }

        case editing(EditingMode)
        case browsing

        var isEditing: Bool {
            return self != .browsing
        }
    }

    private enum Constants {
        static let switchToTabMinXPadding: CGFloat = 34
    }

    private var mode: Mode = .editing(.text) {
        didSet {
            addressBarButtonsViewController?.controllerMode = mode
        }
    }

    private var isFirstResponder = false {
        didSet {
            updateView()
            updateSwitchToTabBoxAppearance()
            self.addressBarButtonsViewController?.isTextFieldEditorFirstResponder = isFirstResponder
            self.clickPoint = nil // reset click point if the address bar activated during click
        }
    }

    private var isHomePage = false {
        didSet {
            updateView()
            suggestionContainerViewModel.isHomePage = isHomePage
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private var tabViewModelCancellables = Set<AnyCancellable>()
    private var eventMonitorCancellables = Set<AnyCancellable>()

    /// save mouse-down position to handle same-place clicks outside of the Address Bar to remove first responder
    private var clickPoint: NSPoint?

    required init?(coder: NSCoder) {
        fatalError("AddressBarViewController: Bad initializer")
    }

    init?(coder: NSCoder,
          tabCollectionViewModel: TabCollectionViewModel,
          burnerMode: BurnerMode,
          popovers: NavigationBarPopovers?,
          isSearchBox: Bool = false,
          onboardingPixelReporter: OnboardingAddressBarReporting = OnboardingPixelReporter()) {
        self.tabCollectionViewModel = tabCollectionViewModel
        self.popovers = popovers
        self.suggestionContainerViewModel = SuggestionContainerViewModel(
            isHomePage: tabViewModel?.tab.content == .newtab,
            isBurner: burnerMode.isBurner,
            suggestionContainer: SuggestionContainer(burnerMode: burnerMode))
        self.isBurner = burnerMode.isBurner
        self.onboardingPixelReporter = onboardingPixelReporter
        self.isSearchBox = isSearchBox

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.masksToBounds = false

        addressBarTextField.isSearchBox = isSearchBox
        addressBarTextField.placeholderString = UserText.addressBarPlaceholder
        addressBarTextField.setAccessibilityIdentifier("AddressBarViewController.addressBarTextField")

        switchToTabBox.isHidden = true
        switchToTabLabel.attributedStringValue = SuggestionTableCellView.switchToTabAttributedString

        updateView()
        // only activate active text field leading constraint on its appearance to avoid constraint conflicts
        activeTextFieldMinXConstraint.isActive = false
        addressBarTextField.tabCollectionViewModel = tabCollectionViewModel
        addressBarTextField.onboardingDelegate = onboardingPixelReporter
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
            refreshAddressBarAppearance(self)

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
            NSApp.publisher(for: \.effectiveAppearance)
                .dropFirst()
                .sink { [weak self] _ in
                    self?.refreshAddressBarAppearance(nil)
                }
                .store(in: &cancellables)

            addMouseMonitors()
        }
        subscribeToSelectedTabViewModel()
        subscribeToAddressBarValue()
        subscribeToButtonsWidth()
        subscribeForShadowViewUpdates()
    }

    // swiftlint:disable notification_center_detachment
    override func viewWillDisappear() {
        NotificationCenter.default.removeObserver(self)
        eventMonitorCancellables.removeAll()
    }
    // swiftlint:enable notification_center_detachment

    override func viewDidLayout() {
        super.viewDidLayout()

        addressBarTextField.viewDidLayout()
    }

    func escapeKeyDown() -> Bool {
        guard isFirstResponder else { return false }

        if mode.isEditing {
            addressBarTextField.escapeKeyDown()
            return true
        }

        view.window?.makeFirstResponder(nil)

        return true
    }

    @IBSegueAction func createAddressBarButtonsViewController(_ coder: NSCoder) -> AddressBarButtonsViewController? {
        let controller = AddressBarButtonsViewController(coder: coder, tabCollectionViewModel: tabCollectionViewModel, popovers: popovers)

        self.addressBarButtonsViewController = controller
        controller?.delegate = self
        return addressBarButtonsViewController
    }

    @IBOutlet var shadowView: ShadowView!

    private func subscribeToSelectedTabViewModel() {
        tabCollectionViewModel.$selectedTabViewModel
            .sink { [weak self] tabViewModel in
                guard let self else { return }

                self.tabViewModel = tabViewModel
                tabViewModelCancellables.removeAll()

                subscribeToTabContent()
                subscribeToPassiveAddressBarString()
                subscribeToProgressEvents()

                // don't resign first responder on tab switching
                clickPoint = nil
            }
            .store(in: &cancellables)
    }

    private func subscribeToAddressBarValue() {
        addressBarTextField.$value
            .sink { [weak self] value in
                guard let self else { return }

                updateMode(value: value)
                addressBarButtonsViewController?.textFieldValue = value
                updateView()
                updateSwitchToTabBoxAppearance()
            }
            .store(in: &cancellables)
    }

    private func subscribeToTabContent() {
        tabViewModel?.tab.$content
            .map { $0 == .newtab }
            .assign(to: \.isHomePage, onWeaklyHeld: self)
            .store(in: &tabViewModelCancellables)
    }

    private func subscribeToPassiveAddressBarString() {
        guard let tabViewModel else {
            passiveTextField.stringValue = ""
            return
        }
        tabViewModel.$passiveAddressBarAttributedString
            .receive(on: DispatchQueue.main)
            .assign(to: \.attributedStringValue, onWeaklyHeld: passiveTextField)
            .store(in: &tabViewModelCancellables)
    }

    private func subscribeToProgressEvents() {
        guard let tabViewModel else {
            progressIndicator.hide(animated: false)
            return
        }

        func shouldShowLoadingIndicator(for tabViewModel: TabViewModel, isLoading: Bool, error: Error?) -> Bool {
            if isLoading,
               let url = tabViewModel.tab.content.urlForWebView,
               url.navigationalScheme?.isHypertextScheme == true,
               !url.isDuckDuckGoSearch, !url.isDuckPlayer,
               error == nil {
                return true
            } else {
                return false
            }
        }

        if shouldShowLoadingIndicator(for: tabViewModel, isLoading: tabViewModel.isLoading, error: tabViewModel.tab.error) {
            progressIndicator.show(progress: tabViewModel.progress, startTime: tabViewModel.loadingStartTime)
        } else {
            progressIndicator.hide(animated: false)
        }

        tabViewModel.$progress
            .sink { [weak self] value in
                guard tabViewModel.isLoading,
                      let progressIndicator = self?.progressIndicator,
                      progressIndicator.isProgressShown
                else { return }

                progressIndicator.increaseProgress(to: value)
            }
            .store(in: &tabViewModelCancellables)

        tabViewModel.$isLoading.combineLatest(tabViewModel.tab.$error)
            .debounce(for: 0.1, scheduler: RunLoop.main)
            .sink { [weak self] isLoading, error in
                guard let progressIndicator = self?.progressIndicator else { return }

                if shouldShowLoadingIndicator(for: tabViewModel, isLoading: isLoading, error: error) {
                    progressIndicator.show(progress: tabViewModel.progress, startTime: tabViewModel.loadingStartTime)

                } else if progressIndicator.isProgressShown {
                    progressIndicator.finishAndHide()
                }
            }
            .store(in: &tabViewModelCancellables)
    }

    private func subscribeToButtonsWidth() {
        addressBarButtonsViewController!.$buttonsWidth
            .sink { [weak self] value in
                self?.layoutTextFields(withMinX: value)
            }
            .store(in: &cancellables)
    }

    @Published var isSuggestionsWindowVisible: Bool = false

    private func subscribeForShadowViewUpdates() {
        addressBarTextField.isSuggestionWindowVisiblePublisher
            .sink { [weak self] isSuggestionsWindowVisible in
                self?.isSuggestionsWindowVisible = isSuggestionsWindowVisible
                self?.updateShadowView(isSuggestionsWindowVisible)
                if isSuggestionsWindowVisible {
                    self?.layoutShadowView()
                }
            }
            .store(in: &cancellables)

        view.superview?.publisher(for: \.frame)
            .sink { [weak self] _ in
                self?.layoutShadowView()
            }
            .store(in: &cancellables)
    }

    var accentColor: NSColor {
        return isBurner ? NSColor.burnerAccent : NSColor.controlAccentColor
    }

    private func updateView() {
        let isFirstResponderOrBigSearchBox = isFirstResponder || isSearchBox

        let isPassiveTextFieldHidden = isFirstResponderOrBigSearchBox || mode.isEditing
        addressBarTextField.alphaValue = isPassiveTextFieldHidden ? 1 : 0
        passiveTextField.alphaValue = isPassiveTextFieldHidden ? 0 : 1

        updateShadowViewPresence(isFirstResponderOrBigSearchBox)
        inactiveBackgroundView.alphaValue = isFirstResponderOrBigSearchBox ? 0 : 1
        activeBackgroundView.alphaValue = isFirstResponderOrBigSearchBox ? 1 : 0

        let isKey = self.view.window?.isKeyWindow == true

        if isSearchBox {
            let appearance = addressBarTextField.homePagePreferredAppearance ?? NSApp.effectiveAppearance

            appearance.performAsCurrentDrawingAppearance {
                activeOuterBorderView.alphaValue = isKey && isFirstResponder ? 1 : 0
                activeOuterBorderView.backgroundColor = accentColor.withAlphaComponent(0.2)
                activeBackgroundView.borderWidth = 1.0
                activeBackgroundView.borderColor = isKey && isFirstResponder ? accentColor.withAlphaComponent(0.8) : NSColor.homePageAddressBarBorder
                activeBackgroundView.backgroundColor = NSColor.homePageAddressBarBackground
            }
        } else {
            activeOuterBorderView.alphaValue = isKey && isFirstResponder && isHomePage ? 1 : 0
            activeOuterBorderView.backgroundColor = accentColor.withAlphaComponent(0.2)
            activeBackgroundView.borderColor = accentColor.withAlphaComponent(0.8)
        }

        addressBarTextField.placeholderString = tabViewModel?.tab.content == .newtab ? UserText.addressBarPlaceholder : ""
    }

    private func updateSwitchToTabBoxAppearance() {
        guard case .editing(.openTabSuggestion) = mode,
            addressBarTextField.isVisible, let editor = addressBarTextField.editor else {
            switchToTabBox.isHidden = true
            switchToTabBox.alphaValue = 0
            return
        }

        if !switchToTabBox.isVisible {
            switchToTabBox.isShown = true
            switchToTabBox.alphaValue = 0
        }
        // update box position on the next pass after text editor layout is updated
        DispatchQueue.main.async {
            self.switchToTabBox.alphaValue = 1
            self.switchToTabBoxMinXConstraint.constant = editor.textSize.width + Constants.switchToTabMinXPadding
        }
    }

    private func updateShadowViewPresence(_ isFirstResponder: Bool) {
        guard isFirstResponder, view.window?.isPopUpWindow == false else {
            shadowView.removeFromSuperview()
            return
        }
        if shadowView.superview == nil {
            updateShadowView(addressBarTextField.isSuggestionWindowVisible)
            view.window?.contentView?.addSubview(shadowView)
            layoutShadowView()
        }
    }

    private func updateShadowView(_ isSuggestionsWindowVisible: Bool) {
        shadowView.shadowSides = isSuggestionsWindowVisible ? [.left, .top, .right] : []
        shadowView.shadowColor = isSuggestionsWindowVisible ? .suggestionsShadow : .clear
        shadowView.shadowRadius = isSuggestionsWindowVisible ? 8.0 : 0.0

        activeOuterBorderView.isHidden = isSuggestionsWindowVisible || view.window?.isKeyWindow != true
        activeBackgroundView.isHidden = isSuggestionsWindowVisible
        activeBackgroundViewWithSuggestions.isHidden = !isSuggestionsWindowVisible
        if isSearchBox {
            innerBorderView.isHidden = true
        }
    }

    private func layoutShadowView() {
        guard let superview = shadowView.superview else { return }

        let winFrame = self.view.convert(self.view.bounds, to: nil)
        let frame = superview.convert(winFrame, from: nil)
        shadowView.frame = frame
    }

    private func updateMode(value: AddressBarTextField.Value? = nil) {
        switch value ?? self.addressBarTextField.value {
        case .text: self.mode = .editing(.text)
        case .url(urlString: _, url: _, userTyped: let userTyped): self.mode = userTyped ? .editing(.url) : .browsing
        case .suggestion(let suggestionViewModel):
            switch suggestionViewModel.suggestion {
            case .phrase, .unknown:
                self.mode = .editing(.text)
            case .website, .bookmark, .historyEntry, .internalPage:
                self.mode = .editing(.url)
            case .openTab:
                self.mode = .editing(.openTabSuggestion)
            }
        }
    }

    @objc private func refreshAddressBarAppearance(_ sender: Any?) {
        self.updateMode()
        self.addressBarButtonsViewController?.updateButtons()

        guard let window = view.window, NSApp.runType != .unitTests else { return }

        if isSearchBox {
            let appearance = addressBarTextField.homePagePreferredAppearance ?? NSApp.effectiveAppearance

            appearance.performAsCurrentDrawingAppearance {
                activeBackgroundView.borderWidth = 1.0
                activeBackgroundView.borderColor = NSColor.homePageAddressBarBorder
                activeBackgroundView.backgroundColor = NSColor.homePageAddressBarBackground
                activeBackgroundViewWithSuggestions.borderColor = NSColor.homePageAddressBarBorder
                activeBackgroundViewWithSuggestions.backgroundColor = NSColor.homePageAddressBarBackground
                switchToTabBox.backgroundColor = NSColor.homePageAddressBarBackground
            }

        } else {
            NSAppearance.withAppAppearance {
                if window.isKeyWindow {
                    activeBackgroundView.borderWidth = 2.0
                    activeBackgroundView.borderColor = accentColor.withAlphaComponent(0.6)
                    activeBackgroundView.backgroundColor = NSColor.addressBarBackground
                    switchToTabBox.backgroundColor = NSColor.navigationBarBackground.blended(with: .addressBarBackground)

                    activeOuterBorderView.isHidden = !isHomePage
                } else {
                    activeBackgroundView.borderWidth = 0
                    activeBackgroundView.borderColor = nil
                    activeBackgroundView.backgroundColor = NSColor.inactiveSearchBarBackground
                    switchToTabBox.backgroundColor = NSColor.navigationBarBackground.blended(with: .inactiveSearchBarBackground)

                    activeOuterBorderView.isHidden = true
                }
            }
        }
    }

    private func layoutTextFields(withMinX minX: CGFloat) {
        self.passiveTextFieldMinXConstraint.constant = minX
        // adjust min-x to passive text field when “Search or enter” placeholder is displayed (to prevent placeholder overlapping buttons)
        self.activeTextFieldMinXConstraint.constant = (!self.isFirstResponder || self.mode.isEditing)
            ? minX : Self.defaultActiveTextFieldMinX
    }

}

extension AddressBarViewController {

    @objc func textFieldFirstReponderNotification(_ notification: Notification) {
        if view.window?.firstResponder == addressBarTextField.currentEditor() {
            isFirstResponder = true
            activeTextFieldMinXConstraint.isActive = true
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
        eventMonitorCancellables.removeAll()
        NSEvent.addLocalCancellableMonitor(forEventsMatching: .leftMouseDown) { [weak self] event in
            guard let self else { return event }
            return self.mouseDown(with: event)
        }.store(in: &eventMonitorCancellables)
        NSEvent.addLocalCancellableMonitor(forEventsMatching: .leftMouseUp) { [weak self] event in
            guard let self else { return event }
            return self.mouseUp(with: event)
        }.store(in: &eventMonitorCancellables)
        NSEvent.addLocalCancellableMonitor(forEventsMatching: .rightMouseDown) { [weak self] event in
            guard let self else { return event }
            return self.rightMouseDown(with: event)
        }.store(in: &eventMonitorCancellables)
    }

    func mouseDown(with event: NSEvent) -> NSEvent? {
        self.clickPoint = nil
        guard let window = self.view.window, event.window === window else { return event }

        if let point = self.view.mouseLocationInsideBounds(event.locationInWindow) {
            guard self.view.window?.firstResponder !== addressBarTextField.currentEditor(),
                  self.view.hitTest(point)?.shouldShowArrowCursor == false
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

        } else if window.isMainWindow {
            self.clickPoint = window.convertPoint(toScreen: event.locationInWindow)
        }
        return event
    }

    func rightMouseDown(with event: NSEvent) -> NSEvent? {
        guard event.window === self.view.window else { return event }
        // Convert the point to view system
        let pointInView = view.convert(event.locationInWindow, from: nil)

        // If the view where the touch occurred is outside the AddressBar forward the event
        guard let viewWithinAddressBar = view.hitTest(pointInView) else { return event }

        // If the farthest view of the point location is a NSButton or LottieAnimationView don't show contextual menu
        guard viewWithinAddressBar.shouldShowArrowCursor == false else { return nil }

        // The event location is not a button so we can forward the event to the textfield
        addressBarTextField.rightMouseDown(with: event)
        return nil
    }

    private static let maxClickReleaseDistanceToResignFirstResponder: CGFloat = 4

    func mouseUp(with event: NSEvent) -> NSEvent? {
        // click (same position down+up) outside of the field: resign first responder
        guard let window = self.view.window, event.window === window,
              window.firstResponder === addressBarTextField.currentEditor(),
              let clickPoint,
              clickPoint.distance(to: window.convertPoint(toScreen: event.locationInWindow)) <= Self.maxClickReleaseDistanceToResignFirstResponder else {
            return event
        }

        self.view.window?.makeFirstResponder(nil)

        return event
    }

}

extension AddressBarViewController: AddressBarButtonsViewControllerDelegate {

    func addressBarButtonsViewControllerClearButtonClicked(_ addressBarButtonsViewController: AddressBarButtonsViewController) {
        addressBarTextField.clearValue()
    }

}

fileprivate extension NSView {

    var shouldShowArrowCursor: Bool {
        self is NSButton || self is LottieAnimationView
    }

}
