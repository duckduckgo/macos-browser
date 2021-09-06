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

final class WindowsManager {

    class var windows: [NSWindow] {
        return NSApplication.shared.windows
    }

    class func closeWindows(except window: NSWindow? = nil) {
        NSApplication.shared.windows.forEach {
            if $0 != window {
                $0.close()
            }
        }
    }

    @discardableResult
    class func openNewWindow(with tabCollectionViewModel: TabCollectionViewModel? = nil,
                             droppingPoint: NSPoint? = nil,
                             showWindow: Bool = true,
                             withBurnerTab: Bool = false) -> NSWindow? {
        let mainWindowController = makeNewWindow(tabCollectionViewModel: tabCollectionViewModel, withBurnerTab: withBurnerTab)

        if let droppingPoint = droppingPoint {
            mainWindowController.window?.setFrameOrigin(droppingPoint: droppingPoint)
        }
        if showWindow {
            mainWindowController.showWindow(self)
        } else {
            mainWindowController.orderWindowBack(self)
        }

        return mainWindowController.window
    }

    class func openNewWindow(with tab: Tab, droppingPoint: NSPoint? = nil) {
        let tabCollection = TabCollection()
        tabCollection.append(tab: tab)
        openNewWindow(with: TabCollectionViewModel(tabCollection: tabCollection), droppingPoint: droppingPoint)
    }

    class func openNewWindow(with initialUrl: URL) {
        let mainWindowController = makeNewWindow()
        mainWindowController.showWindow(self)

        let mainViewController = mainWindowController.mainViewController
        guard let newTab = mainViewController.tabCollectionViewModel.tabCollection.tabs.first else {
            os_log("MainWindowController: Failed to get initial tab", type: .error)
            return
        }

        newTab.content = .url(initialUrl)
    }

    private class func makeNewWindow(tabCollectionViewModel: TabCollectionViewModel? = nil, withBurnerTab: Bool = false) -> MainWindowController {
        let mainViewController: MainViewController
        do {
            mainViewController = try NSException.catch {
                NSStoryboard(name: "Main", bundle: .main)
                    .instantiateController(identifier: .mainViewController) { coder -> MainViewController? in
                        let model = tabCollectionViewModel ?? TabCollectionViewModel.makeWithDefaultTab(isBurner: withBurnerTab)
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

        return MainWindowController(mainViewController: mainViewController)
    }

}

fileprivate extension NSStoryboard.SceneIdentifier {
    static let mainViewController = NSStoryboard.SceneIdentifier("mainViewController")
}
