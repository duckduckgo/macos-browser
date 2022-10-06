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
import os.log
import Combine

final class MainWindowController: NSWindowController {

    private static let windowFrameSaveName = "MainWindow"
    private var fireViewModel: FireViewModel

    var mainViewController: MainViewController {
        // swiftlint:disable force_cast
        contentViewController as! MainViewController
        // swiftlint:enable force_cast
    }

    var titlebarView: NSView? {
        return window?.standardWindowButton(.closeButton)?.superview
    }

    init(mainViewController: MainViewController, popUp: Bool, fireViewModel: FireViewModel = FireCoordinator.fireViewModel) {
        let makeWindow: (NSRect) -> NSWindow = popUp ? PopUpWindow.init(frame:) : MainWindow.init(frame:)

        let size = mainViewController.view.frame.size
        let moveToCenter = CGAffineTransform(translationX: ((NSScreen.main?.frame.width ?? 1024) - size.width) / 2,
                                             y: ((NSScreen.main?.frame.height ?? 790) - size.height) / 2)
        let frame = NSRect(origin: (NSScreen.main?.frame.origin ?? .zero).applying(moveToCenter),
                           size: size)

        let window = makeWindow(frame)
        window.contentViewController = mainViewController
        self.fireViewModel = fireViewModel

        super.init(window: window)

        setupWindow()
        setupToolbar()
        subscribeToTrafficLightsAlpha()
        subscribeToShouldPreventUserInteraction()
        subscribeToResolutionChange()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindow() {
        window?.delegate = self
        window?.setFrameAutosaveName(Self.windowFrameSaveName)
        
        #if !DEBUG && !REVIEW
        if !OnboardingViewModel().onboardingFinished {
            mainViewController.tabCollectionViewModel.selectedTabViewModel?.tab.startOnboarding()
        }
        #endif
    }
    
    private func subscribeToResolutionChange() {
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: NSApplication.shared,
                                               queue: OperationQueue.main) { [weak self] _ in
            self?.resizeWindowIfNeeded()
        }
    }
    
    private func resizeWindowIfNeeded() {
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

    private var shouldPreventUserInteractionCancellable: AnyCancellable?
    private func subscribeToShouldPreventUserInteraction() {
        shouldPreventUserInteractionCancellable = fireViewModel.shouldPreventUserInteraction
            .dropFirst()
            .removeDuplicates()
            .sink(receiveValue: { [weak self] shouldPreventUserInteraction in
                self?.moveTabBarView(toTitlebarView: !shouldPreventUserInteraction)
                self?.userInteraction(prevented: shouldPreventUserInteraction)
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
        WindowControllersManager.shared.register(self)
    }

}

extension MainWindowController: NSWindowDelegate {

    func window(_ window: NSWindow,
                willUseFullScreenPresentationOptions: NSApplication.PresentationOptions) -> NSApplication.PresentationOptions {
        return [.fullScreen, .autoHideMenuBar]
    }

    func windowDidBecomeKey(_ notification: Notification) {
        mainViewController.windowDidBecomeMain()
        mainViewController.navigationBarViewController.windowDidBecomeMain()

        if (notification.object as? NSWindow)?.isPopUpWindow == false {
            WindowControllersManager.shared.lastKeyMainWindowController = self
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        mainViewController.windowDidResignKey()
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        mainViewController.tabBarViewController.draggingSpace.isHidden = true
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
            WindowControllersManager.shared.unregister(self)
        }
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
                refreshButton,
                optionsButton,
                bookmarkListButton,
                passwordManagementButton,
                addressBarViewController?.addressBarTextField,
                addressBarViewController?.passiveTextField
        ]
    }

}
