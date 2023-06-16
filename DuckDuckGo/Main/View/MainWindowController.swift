//
//  MainWindowController.swift
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
import Common
import DependencyInjection

#if swift(>=5.9)
@Injectable
#endif
@MainActor
final class MainWindowController: NSWindowController, Injectable {
    let dependencies: DependencyStorage

    @Injected
    var windowManager: WindowManagerProtocol
    @Injected
    var fireViewModel: FireViewModel

    private static let windowFrameSaveName = "MainWindow"
    private static var knownFullScreenMouseDetectionWindows = Set<NSValue>()

    var mainViewController: MainViewController {
        // swiftlint:disable force_cast
        contentViewController as! MainViewController
        // swiftlint:enable force_cast
    }

    var titlebarView: NSView? {
        return window?.standardWindowButton(.closeButton)?.superview
    }

    init(mainViewController: MainViewController, popUp: Bool, dependencyProvider: DependencyProvider) {
        self.dependencies = .init(dependencyProvider)

        let size = mainViewController.view.frame.size
        let moveToCenter = CGAffineTransform(translationX: ((NSScreen.main?.frame.width ?? 1024) - size.width) / 2,
                                             y: ((NSScreen.main?.frame.height ?? 790) - size.height) / 2)
        let frame = NSRect(origin: (NSScreen.main?.frame.origin ?? .zero).applying(moveToCenter),
                           size: size)

        let window = popUp ? PopUpWindow(frame: frame) : MainWindow(frame: frame)
        window.contentViewController = mainViewController

        super.init(window: window)

        setupWindow()
        setupToolbar()
        subscribeToTrafficLightsAlpha()
        subscribeToBurningData()
        subscribeToResolutionChange()
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private var shouldShowOnboarding: Bool {
#if DEBUG
        return false
#else
        let onboardingIsComplete = OnboardingViewModel().onboardingFinished || LocalStatisticsStore().waitlistUnlocked
        return !onboardingIsComplete
#endif
    }

    private func setupWindow() {
        window?.delegate = self
        window?.setFrameAutosaveName(Self.windowFrameSaveName)

        if shouldShowOnboarding {
            mainViewController.tabCollectionViewModel.selectedTabViewModel?.tab.startOnboarding()
        }
    }

    private func subscribeToResolutionChange() {
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeScreenParameters), name: NSApplication.didChangeScreenParametersNotification, object: NSApp)
    }

    @objc
    private func didChangeScreenParameters(_ notification: NSNotification) {
        if let visibleWindowFrame = window?.screen?.visibleFrame,
           let windowFrame = window?.frame {

            if windowFrame.width > visibleWindowFrame.width || windowFrame.height > visibleWindowFrame.height {
                window?.performZoom(nil)
            }
        }
    }

    private func setupToolbar() {
        // Empty toolbar ensures that window buttons are centered vertically
        window?.toolbar = NSToolbar()
        window?.toolbar?.showsBaselineSeparator = true

        moveTabBarView(toTitlebarView: true)
    }

    private var trafficLightsAlphaCancellable: AnyCancellable?
    private func subscribeToTrafficLightsAlpha() {
        guard let tabBarViewController = mainViewController.tabBarViewController else {
            assertionFailure("MainWindowController: tabBarViewController is nil" )
            return
        }

        // slide tabs to the left in full screen
        trafficLightsAlphaCancellable = window?.standardWindowButton(.closeButton)?
            .publisher(for: \.alphaValue)
            .map { alphaValue in TabBarViewController.HorizontalSpace.pinnedTabsScrollViewPadding.rawValue * alphaValue }
            .assign(to: \.constant, onWeaklyHeld: tabBarViewController.pinnedTabsViewLeadingConstraint)
    }

    private var burningDataCancellable: AnyCancellable?
    private func subscribeToBurningData() {
        burningDataCancellable = fireViewModel.fire.$burningData
            .dropFirst()
            .removeDuplicates()
            .sink(receiveValue: { [weak self] burningData in
                guard let self else { return }
                self.userInteraction(prevented: burningData != nil)
            })
    }

    func userInteraction(prevented: Bool) {
        mainViewController.tabCollectionViewModel.changesEnabled = !prevented
        mainViewController.tabCollectionViewModel.selectedTabViewModel?.tab.contentChangeEnabled = !prevented

        mainViewController.tabBarViewController.fireButton.isEnabled = !prevented
        mainViewController.navigationBarViewController.controlsForUserPrevention.forEach { $0?.isEnabled = !prevented }

        NSApplication.shared.mainMenuTyped.autoupdatingMenusForUserPrevention.forEach { $0.autoenablesItems = !prevented }
        NSApplication.shared.mainMenuTyped.menuItemsForUserPrevention.forEach { $0.isEnabled = !prevented }

        if prevented {
            window?.styleMask.remove(.closable)
            mainViewController.view.makeMeFirstResponder()
        } else {
            window?.styleMask.update(with: .closable)
            mainViewController.adjustFirstResponder()
        }
    }

    private func moveTabBarView(toTitlebarView: Bool) {
        guard let newParentView = toTitlebarView ? titlebarView : mainViewController.view,
              let tabBarViewController = mainViewController.tabBarViewController else {
            assertionFailure("Failed to move tab bar view")
            return
        }

        tabBarViewController.view.removeFromSuperview()
        if toTitlebarView {
            newParentView.addSubview(tabBarViewController.view)
        } else {
            newParentView.addSubview(tabBarViewController.view, positioned: .below, relativeTo: mainViewController.fireViewController.view)
        }

        tabBarViewController.view.frame = newParentView.bounds
        tabBarViewController.view.translatesAutoresizingMaskIntoConstraints = false
        let constraints = tabBarViewController.view.addConstraints(to: newParentView, [
            .leading: .leading(),
            .trailing: .trailing(),
            .top: .top(),
            .height: .const(40.0)
        ])
        NSLayoutConstraint.activate(constraints)
    }

    override func showWindow(_ sender: Any?) {
        window?.makeKeyAndOrderFront(sender)
        register()
    }

    func orderWindowBack(_ sender: Any?) {
        window?.orderBack(sender)
        register()
    }

    private func register() {
        windowManager.register(self)
    }

}

extension MainWindowController: NSWindowDelegate {

    func windowDidBecomeKey(_ notification: Notification) {
        mainViewController.windowDidBecomeMain()

        if (notification.object as? NSWindow)?.isPopUpWindow == false {
            windowManager.lastKeyMainWindowController = self
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        mainViewController.windowDidResignKey()
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        mainViewController.tabBarViewController.draggingSpace.isHidden = true
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        // fix NSToolbarFullScreenWindow occurring beneath the MainWindow
        // https://app.asana.com/0/1177771139624306/1203853030672990/f
        // NSApp should be active at the moment of window ordering otherwise toolbar would disappear on activation
        for window in NSApp.windows {
            let windowValue = NSValue(nonretainedObject: window)

            guard window.className.contains("NSFullScreenMouseDetectionWindow"),
                  !Self.knownFullScreenMouseDetectionWindows.contains(windowValue),
                  window.screen == self.window!.screen else { continue }

            // keep record of NSFullScreenMouseDetectionWindow to avoid adding other‘s windows
            Self.knownFullScreenMouseDetectionWindows.insert(windowValue)
            window.onDeinit {
                Self.knownFullScreenMouseDetectionWindows.remove(windowValue)
            }

            // add NSFullScreenMouseDetectionWindow as a child window to activate the app without revealing all of its windows
            let activeApp = NSWorkspace.shared.frontmostApplication
            if activeApp != .current {
                self.window!.addChildWindow(window, ordered: .above)
            }

            // remove the child window and reactivate initially active app as soon as current app becomes active
            // otherwise the fullscreen will reactivate its Space when switching to window in another Space
            var cancellable: AnyCancellable!
            cancellable = NSApp.isActivePublisher().dropFirst().sink { [weak self, weak window] _ in
                withExtendedLifetime(cancellable) {
                    if let activeApp, activeApp != .current {
                        activeApp.activate()
                    }

                    if let self, let window, self.window?.childWindows?.contains(window) == true {
                        self.window?.removeChildWindow(window)
                    }
                    cancellable = nil
                }
            }

            break
        }
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        mainViewController.tabBarViewController.draggingSpace.isHidden = false
    }

    func windowWillClose(_ notification: Notification) {
        mainViewController.windowWillClose()

        window?.resignKey()
        window?.resignMain()

        // Unregistering triggers deinitialization of this object.
        // Because it's also the delegate, deinit within this method caused crash
        DispatchQueue.main.async {
            self.windowManager.unregister(self)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Animate fire for Burner Window when closing
        guard mainViewController.tabCollectionViewModel.isBurner else {
            return true
        }
        Task {
            await mainViewController.fireViewController.animateFireWhenClosing()
            sender.close()
        }
        return false
    }

}

fileprivate extension MainMenu {

    var menuItemsForUserPrevention: [NSMenuItem] {
        return [
            newWindowMenuItem,
            newTabMenuItem,
            openLocationMenuItem,
            closeWindowMenuItem,
            closeAllWindowsMenuItem,
            closeTabMenuItem,
            importBrowserDataMenuItem,
            manageBookmarksMenuItem,
            importBookmarksMenuItem,
            preferencesMenuItem
        ]
    }

    var autoupdatingMenusForUserPrevention: [NSMenu] {
        return [
            preferencesMenuItem.menu,
            manageBookmarksMenuItem.menu
        ].compactMap { $0 }
    }

}

fileprivate extension NavigationBarViewController {

    var controlsForUserPrevention: [NSControl?] {
        return [goBackButton,
                goForwardButton,
                refreshOrStopButton,
                optionsButton,
                bookmarkListButton,
                passwordManagementButton,
                addressBarViewController?.addressBarTextField,
                addressBarViewController?.passiveTextField
        ]
    }

}
