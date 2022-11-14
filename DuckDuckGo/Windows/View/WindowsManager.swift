//
//  WindowsManager.swift
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
import BrowserServicesKit

final class WindowsManager {

    class var windows: [NSWindow] {
        return NSApplication.shared.windows
    }

    class func closeWindows(except window: NSWindow? = nil) {
        for controller in WindowControllersManager.shared.mainWindowControllers where controller.window !== window {
            controller.close()
        }
    }

    @discardableResult
    class func openNewWindow(with tabCollectionViewModel: TabCollectionViewModel? = nil,
                             droppingPoint: NSPoint? = nil,
                             contentSize: NSSize? = nil,
                             showWindow: Bool = true,
                             popUp: Bool = false,
                             lazyLoadTabs: Bool = false) -> MainWindow? {
        let mainWindowController = makeNewWindow(tabCollectionViewModel: tabCollectionViewModel, popUp: popUp)

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
    class func openNewWindow(with tab: Tab, droppingPoint: NSPoint? = nil, contentSize: NSSize? = nil, popUp: Bool = false) -> MainWindow? {
        let tabCollection = TabCollection()
        tabCollection.append(tab: tab)

        let tabCollectionViewModel: TabCollectionViewModel = {
            if popUp {
                return .init(tabCollection: tabCollection, pinnedTabsManager: nil)
            }
            return .init(tabCollection: tabCollection)
        }()

        return openNewWindow(with: tabCollectionViewModel,
                      droppingPoint: droppingPoint,
                      contentSize: contentSize,
                      popUp: popUp)
    }

    class func openNewWindow(with initialUrl: URL, parentTab: Tab? = nil) {
        openNewWindow(with: Tab(content: .contentFromURL(initialUrl), parentTab: parentTab))
    }

    class func openNewWindow(with tabCollection: TabCollection, droppingPoint: NSPoint? = nil, contentSize: NSSize? = nil, popUp: Bool = false) {
        let tabCollectionViewModel = TabCollectionViewModel(tabCollection: tabCollection)
        openNewWindow(with: tabCollectionViewModel,
                      droppingPoint: droppingPoint,
                      contentSize: contentSize,
                      popUp: popUp)
        tabCollectionViewModel.setUpLazyLoadingIfNeeded()
    }

    class func openPopUpWindow(with tab: Tab, contentSize: NSSize?) {
        if let mainWindowController = WindowControllersManager.shared.lastKeyMainWindowController,
           mainWindowController.window?.styleMask.contains(.fullScreen) == true,
           mainWindowController.window?.isPopUpWindow == false {
            mainWindowController.mainViewController.tabCollectionViewModel.insertChild(tab: tab, selected: true)
        } else {
            self.openNewWindow(with: tab, contentSize: contentSize, popUp: true)
        }
    }

    private class func makeNewWindow(tabCollectionViewModel: TabCollectionViewModel? = nil,
                                     contentSize: NSSize? = nil,
                                     popUp: Bool = false) -> MainWindowController {
        let mainViewController: MainViewController
        do {
            mainViewController = try NSException.catch {
                NSStoryboard(name: "Main", bundle: .main)
                    .instantiateController(identifier: .mainViewController) { coder -> MainViewController? in
                        let model = tabCollectionViewModel ?? TabCollectionViewModel()
                        return MainViewController(coder: coder, tabCollectionViewModel: model)
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

        return MainWindowController(mainViewController: mainViewController, popUp: popUp)
    }

}

fileprivate extension NSStoryboard.SceneIdentifier {
    static let mainViewController = NSStoryboard.SceneIdentifier("mainViewController")
}
