//
//  WindowManager.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

@MainActor
protocol WindowManagerProtocol: AnyObject {

    var windows: [NSWindow] { get }

    var didRegisterWindowController: PassthroughSubject<(MainWindowController), Never> { get }
    var didUnregisterWindowController: PassthroughSubject<(MainWindowController), Never> { get }

    var lastKeyMainWindowController: MainWindowController? { get set }

    var mainWindowControllers: [MainWindowController] { get }
    var mainWindowControllersPublisher: AnyPublisher<[MainWindowController], Never> { get }

    var didChangeKeyWindowController: AnyPublisher<Void, Never> { get }

    func register(_ windowController: MainWindowController)
    func unregister(_ windowController: MainWindowController)

    @discardableResult
    func openNewWindow(isBurner: Bool, lazyLoadTabs: Bool) -> MainWindow?
    @discardableResult
    func openNewWindow(with tab: Tab, isBurner: Bool, droppingPoint: NSPoint?, contentSize: NSSize?, showWindow: Bool, popUp: Bool) -> MainWindow?
    func openNewWindow(with initialUrl: URL, isBurner: Bool, parentTab: Tab?)
    @discardableResult
    func openNewWindow(with tabCollectionViewModel: TabCollectionViewModel?,
                       isBurner: Bool,
                       droppingPoint: NSPoint?,
                       contentSize: NSSize?,
                       showWindow: Bool,
                       popUp: Bool,
                       lazyLoadTabs: Bool) -> MainWindow?

    func openNewWindow(with tabCollection: TabCollection, isBurner: Bool, droppingPoint: NSPoint?, contentSize: NSSize?, popUp: Bool)

    func openPopUpWindow(with tab: Tab, isBurner: Bool, contentSize: NSSize?)
    func beginSheetFromMainWindow(_ viewController: NSViewController)

    func showTab(with content: Tab.TabContent)
    func showBookmarksTab()
    func showPreferencesTab(withSelectedPane pane: PreferencePaneIdentifier?)
    func open(bookmark: Bookmark)

    func show(url: URL?, newTab: Bool)

    func closeWindows(except window: NSWindow?)

    var isInInitialState: Bool { get }
    func updateIsInInitialState()

#if NETWORK_PROTECTION
    func showNetworkProtectionStatus(retry: Bool) async
#endif
}

extension WindowManagerProtocol {

    @discardableResult
    func openNewWindow(isBurner: Bool = false) -> MainWindow? {
        openNewWindow(isBurner: isBurner, lazyLoadTabs: false)
    }

    @discardableResult
    func openNewWindow(with tab: Tab, isBurner: Bool, droppingPoint: NSPoint? = nil, contentSize: NSSize? = nil, showWindow: Bool = true) -> MainWindow? {
        self.openNewWindow(with: tab, isBurner: isBurner, droppingPoint: nil, contentSize: contentSize, showWindow: showWindow, popUp: false)
    }

    @discardableResult
    func openNewWindow(with tabCollectionViewModel: TabCollectionViewModel?,
                       isBurner: Bool = false,
                       droppingPoint: NSPoint? = nil,
                       contentSize: NSSize? = nil,
                       showWindow: Bool = true,
                       popUp: Bool = false) -> MainWindow? {
        openNewWindow(with: tabCollectionViewModel, isBurner: isBurner, droppingPoint: droppingPoint, contentSize: contentSize, showWindow: showWindow, popUp: popUp, lazyLoadTabs: false)
    }

    func openNewWindow(with tabCollection: TabCollection, isBurner: Bool, droppingPoint: NSPoint? = nil, contentSize: NSSize? = nil) {
        openNewWindow(with: tabCollection, isBurner: isBurner, droppingPoint: droppingPoint, contentSize: contentSize, popUp: false)
    }

    func show(url: URL?) {
        show(url: url, newTab: false)
    }

    func openNewWindow(with initialUrl: URL, isBurner: Bool) {
        openNewWindow(with: initialUrl, isBurner: isBurner, parentTab: nil)
    }

    func showPreferencesTab() {
        showPreferencesTab(withSelectedPane: nil)
    }

    func closeWindows() {
        closeWindows(except: nil)
    }

#if NETWORK_PROTECTION
    func showNetworkProtectionStatus() async {
        await showNetworkProtectionStatus(retry: false)
    }
#endif
}

#if swift(>=5.9)
@Injectable
#endif
final class AbstractWindowManagerNestedDependencies: Injectable {
    let dependencies: DependencyStorage

    typealias InjectedDependencies = Tab.Dependencies & TabCollectionViewModel.Dependencies & MainWindowController.Dependencies & MainViewController.Dependencies

    init() {
        fatalError("\(Self.self) should not be instantiated")
    }
}

#if swift(>=5.9)
@Injectable
#endif
@MainActor
final class WindowManager: WindowManagerProtocol, Injectable {

    let dependencies: DependencyStorage

    @Injected
    var pinnedTabsManager: PinnedTabsManager

    private var nestedDependencies: AbstractWindowManagerNestedDependencies.DependencyStorage!

    /**
     * _Initial_ meaning a single window with a single home page tab.
     */
    @Published private(set) var isInInitialState: Bool = true
    @Published private(set) var mainWindowControllers = [MainWindowController]()

    var mainWindowControllersPublisher: AnyPublisher<[MainWindowController], Never> {
        $mainWindowControllers.eraseToAnyPublisher()
    }

    init(dependencyProvider: DependencyProvider, nestedDependencyProvider: (WindowManager) -> AbstractWindowManagerNestedDependencies.DependencyProvider) {
        self.dependencies = .init(dependencyProvider)
        self.nestedDependencies = .init(nestedDependencyProvider(self))
    }

    weak var lastKeyMainWindowController: MainWindowController? {
        didSet {
            if lastKeyMainWindowController != oldValue {
                _didChangeKeyWindowController.send(())
            }
        }
    }

    private var mainWindowController: MainWindowController? {
        return mainWindowControllers.first(where: {
            let isMain = $0.window?.isMainWindow ?? false
            let hasMainChildWindow = $0.window?.childWindows?.contains { $0.isMainWindow } ?? false

            return $0.window?.isPopUpWindow == false && (isMain || hasMainChildWindow)
        })
    }

    var selectedTab: Tab? {
        return mainWindowController?.mainViewController.tabCollectionViewModel.selectedTab
    }

    private let _didChangeKeyWindowController = PassthroughSubject<Void, Never>()
    var didChangeKeyWindowController: AnyPublisher<Void, Never> {
        _didChangeKeyWindowController.eraseToAnyPublisher()
    }
    let didRegisterWindowController = PassthroughSubject<(MainWindowController), Never>()
    let didUnregisterWindowController = PassthroughSubject<(MainWindowController), Never>()

    func register(_ windowController: MainWindowController) {
        guard !mainWindowControllers.contains(windowController) else {
            assertionFailure("Window controller already registered")
            return
        }

        mainWindowControllers.append(windowController)
        didRegisterWindowController.send(windowController)
    }

    func unregister(_ windowController: MainWindowController) {
        guard let idx = mainWindowControllers.firstIndex(of: windowController) else {
            os_log("WindowManager: Window Controller not registered", type: .error)
            return
        }
        mainWindowControllers.remove(at: idx)
        didUnregisterWindowController.send(windowController)
    }

    func updateIsInInitialState() {
        if isInInitialState {

            isInInitialState = mainWindowControllers.isEmpty ||
            (
                mainWindowControllers.count == 1 &&
                mainWindowControllers.first?.mainViewController.tabCollectionViewModel.tabs.count == 1 &&
                mainWindowControllers.first?.mainViewController.tabCollectionViewModel.tabs.first?.content == .homePage &&
                pinnedTabsManager.tabCollection.tabs.isEmpty
            )
        }
    }

    var windows: [NSWindow] {
        return NSApplication.shared.windows
    }

    func closeWindows(except window: NSWindow?) {
        for controller in mainWindowControllers where controller.window !== window {
            controller.close()
        }
    }

    @discardableResult
    func openNewWindow(isBurner: Bool, lazyLoadTabs: Bool) -> MainWindow? {
        openNewWindow(with: nil)
    }

    @discardableResult
    func openNewWindow(with tabCollectionViewModel: TabCollectionViewModel?,
                       isBurner: Bool = false,
                       droppingPoint: NSPoint? = nil,
                       contentSize: NSSize? = nil,
                       showWindow: Bool = true,
                       popUp: Bool = false,
                       lazyLoadTabs: Bool = false) -> MainWindow? {
        let mainWindowController = makeNewWindow(tabCollectionViewModel: tabCollectionViewModel,
                                                 popUp: popUp,
                                                 isBurner: isBurner)

        if let droppingPoint = droppingPoint {
            mainWindowController.window?.setFrameOrigin(droppingPoint: droppingPoint)
        }
        if let contentSize = contentSize {
            let frame = NSRect(origin: droppingPoint ?? CGPoint.zero,
                               size: contentSize)
            mainWindowController.window?.setFrame(frame, display: true)
        }
        if showWindow {
            mainWindowController.showWindow(self)
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            mainWindowController.orderWindowBack(self)
        }

        if lazyLoadTabs {
            mainWindowController.mainViewController.tabCollectionViewModel.setUpLazyLoadingIfNeeded()
        }

        return mainWindowController.window as? MainWindow
    }

    @discardableResult
    func openNewWindow(with tab: Tab, isBurner: Bool = false, droppingPoint: NSPoint? = nil, contentSize: NSSize? = nil, showWindow: Bool = true, popUp: Bool = false) -> MainWindow? {
        let tabCollection = TabCollection()
        tabCollection.append(tab: tab)

        let tabCollectionViewModel: TabCollectionViewModel = popUp
            ? TabCollectionViewModel(tabCollection: tabCollection, isBurner: isBurner, dependencyProvider: nestedDependencies)
            : TabCollectionViewModel(tabCollection: tabCollection,
                                     isBurner: isBurner,
                                     dependencyProvider: TabCollectionViewModel.makeDependencies(pinnedTabsManager: nil, nested: nestedDependencies))

        return openNewWindow(with: tabCollectionViewModel,
                             isBurner: isBurner,
                             droppingPoint: droppingPoint,
                             contentSize: contentSize,
                             showWindow: showWindow,
                             popUp: popUp)
    }

    func openNewWindow(with initialUrl: URL, isBurner: Bool, parentTab: Tab?) {
        openNewWindow(with: Tab(dependencyProvider: nestedDependencies, content: .contentFromURL(initialUrl), parentTab: parentTab, shouldLoadInBackground: true, isBurner: isBurner), isBurner: isBurner)
    }

    func openNewWindow(with tabCollection: TabCollection, isBurner: Bool, droppingPoint: NSPoint? = nil, contentSize: NSSize? = nil, popUp: Bool = false) {
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection, isBurner: isBurner, dependencyProvider: nestedDependencies)
        openNewWindow(with: tabCollectionViewModel,
                      isBurner: isBurner,
                      droppingPoint: droppingPoint,
                      contentSize: contentSize,
                      popUp: popUp)
        tabCollectionViewModel.setUpLazyLoadingIfNeeded()
    }

    func openPopUpWindow(with tab: Tab, isBurner: Bool, contentSize: NSSize?) {
        if let mainWindowController = self.lastKeyMainWindowController,
           mainWindowController.window?.styleMask.contains(.fullScreen) == true,
           mainWindowController.window?.isPopUpWindow == false {
            mainWindowController.mainViewController.tabCollectionViewModel.insert(tab, selected: true)
        } else {
            self.openNewWindow(with: tab, isBurner: isBurner, contentSize: contentSize, popUp: true)
        }
    }

    private func makeNewWindow(tabCollectionViewModel: TabCollectionViewModel? = nil,
                               contentSize: NSSize? = nil,
                               popUp: Bool = false,
                               isBurner: Bool) -> MainWindowController {
        let mainViewController: MainViewController
        do {
            mainViewController = try NSException.catch {
                NSStoryboard(name: "Main", bundle: .main)
                    .instantiateController(identifier: .mainViewController) { coder -> MainViewController? in
                        let model = tabCollectionViewModel ?? TabCollectionViewModel(isBurner: isBurner, dependencyProvider: self.nestedDependencies)
                        assert(model.isBurner == isBurner)
                        return MainViewController(coder: coder, tabCollectionViewModel: model, dependencyProvider: self.nestedDependencies)
                    }
            }
        } catch {
#if DEBUG
            fatalError("WindowsManager.makeNewWindow: \(error)")
#else
            fatalError("WindowsManager.makeNewWindow: the App Bundle seems to be removed")
#endif
        }

        var contentSize = contentSize ?? NSSize(width: 1024, height: 790)
        contentSize.width = min(NSScreen.main?.frame.size.width ?? 1024, max(contentSize.width, 300))
        contentSize.height = min(NSScreen.main?.frame.size.height ?? 790, max(contentSize.height, 300))
        mainViewController.view.frame = NSRect(origin: .zero, size: contentSize)

        return MainWindowController(mainViewController: mainViewController, popUp: popUp, dependencyProvider: nestedDependencies)
    }

}

fileprivate extension NSStoryboard.SceneIdentifier {
    static let mainViewController = NSStoryboard.SceneIdentifier("mainViewController")
}

// MARK: - Opening a url from the external event

extension WindowManager {

    func showBookmarksTab() {
        showTab(with: .bookmarks)
    }

    func showPreferencesTab(withSelectedPane pane: PreferencePaneIdentifier? = nil) {
        showTab(with: .preferences(pane: pane))
    }

    /// Opens a bookmark in a tab, respecting the current modifier keys when deciding where to open the bookmark's URL.
    func open(bookmark: Bookmark) {
        guard let url = bookmark.urlObject else { return }

        if NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
            openNewWindow(with: url, isBurner: false)
        } else if mainWindowController?.mainViewController.view.window?.isPopUpWindow ?? false {
            show(url: url, newTab: true)
        } else if NSApplication.shared.isCommandPressed {
            mainWindowController?.mainViewController.tabCollectionViewModel.appendNewTab(with: .url(url), selected: false)
        } else if selectedTab?.isPinned ?? false { // When selecting a bookmark with a pinned tab active, always open the URL in a new tab
            show(url: url, newTab: true)
        } else {
            show(url: url)
        }
    }

    func show(url: URL?, newTab: Bool) {

        func show(url: URL?, in windowController: MainWindowController) {
            let viewController = windowController.mainViewController
            windowController.window?.makeKeyAndOrderFront(self)

            let tabCollectionViewModel = viewController.tabCollectionViewModel
            let tabCollection = tabCollectionViewModel.tabCollection

            if tabCollection.tabs.count == 1,
               let firstTab = tabCollection.tabs.first,
               case .homePage = firstTab.content,
               !newTab {
                firstTab.setContent(url.map { .url($0) } ?? .homePage)
            } else if let tab = tabCollectionViewModel.selectedTabViewModel?.tab, !newTab {
                tab.setContent(url.map { .url($0) } ?? .homePage)
            } else {
                let newTab = Tab(dependencyProvider: nestedDependencies, content: url.map { .url($0) } ?? .homePage, shouldLoadInBackground: true, isBurner: tabCollectionViewModel.isBurner)
                newTab.setContent(url.map { .url($0) } ?? .homePage)
                tabCollectionViewModel.append(tab: newTab)
            }
        }

        // If there is a main window, open the URL in it
        if let windowController = mainWindowControllers.first(where: { $0.window?.isMainWindow == true && $0.window?.isPopUpWindow == false })
            // If a last key window is available, open the URL in it
            ?? lastKeyMainWindowController
            // If there is any open window on the current screen, open the URL in it
            ?? mainWindowControllers.first(where: { $0.window?.screen == NSScreen.main && $0.window?.isPopUpWindow == false })
            // If there is any window available, open the URL in it
            ?? { mainWindowControllers.first?.window?.isPopUpWindow == false ? mainWindowControllers.first : nil }() {

            show(url: url, in: windowController)
            return
        }

        // Open a new window
        if let url = url {
            openNewWindow(with: url, isBurner: false)
        } else {
            openNewWindow(isBurner: false)
        }
    }

    func showTab(with content: Tab.TabContent) {
        guard let windowController = self.mainWindowController else { return }

        let viewController = windowController.mainViewController
        let tabCollectionViewModel = viewController.tabCollectionViewModel
        tabCollectionViewModel.appendNewTab(with: content)
        windowController.window?.orderFront(nil)
    }

    func beginSheetFromMainWindow(_ viewController: NSViewController) {
        let newWindowController = viewController.wrappedInWindowController()
        guard let newWindow = newWindowController.window,
              let parentWindowController = self.lastKeyMainWindowController
        else {
            assertionFailure("Failed to present \(viewController)")
            return
        }
        parentWindowController.window?.beginSheet(newWindow)
    }

    // MARK: - Network Protection

#if NETWORK_PROTECTION
    func showNetworkProtectionStatus(retry: Bool) async {
        guard let windowController = mainWindowControllers.first else {
            guard !retry else {
                return
            }

            self.openNewWindow()

            // Not proud of this ugly hack... ideally openNewWindow() should let us know when the window is ready
            try? await Task.sleep(interval: 0.5)
            await showNetworkProtectionStatus(retry: true)
            return
        }

        windowController.mainViewController.navigationBarViewController.showNetworkProtectionStatus()
    }
#endif

}

extension Tab {
    var isPinned: Bool {
        self.pinnedTabsManager?.isTabPinned(self) ?? false
    }
}
