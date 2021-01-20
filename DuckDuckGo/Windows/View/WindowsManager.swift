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

extension NSStoryboard {
    static let main = NSStoryboard(name: "Main", bundle: .main)
}

final class WindowsManager {
    static public let shared = WindowsManager()

    var windows: [NSWindow] {
        return NSApplication.shared.windows
    }

    func closeWindows(except activeWindow: NSWindow? = nil) {
        for controller in WindowControllersManager.shared.mainWindowControllers
            where controller.window !== activeWindow {

            controller.window!.close()
        }
    }

    @discardableResult
    func openNewWindow(with tabCollectionViewModel: TabCollectionViewModel,
                       at position: WindowPosition = .auto,
                       with contentSize: NSSize? = nil) -> NSWindow? {
        let mainWindowController = MainWindowController(tabCollectionViewModel: tabCollectionViewModel,
                                                        position: position,
                                                        contentSize: contentSize)

        mainWindowController.showWindow(self)
        
        return mainWindowController.window!
    }

    @discardableResult
    func openNewWindow(with tab: Tab? = nil, at droppingPoint: NSPoint? = nil) -> NSWindow? {
        openNewWindow(with: tab.map(TabCollectionViewModel.init(tab:)) ?? .init(),
                      at: droppingPoint.map(WindowPosition.droppingPoint) ?? .auto)
    }

    @discardableResult
    func openNewWindow(with url: URL) -> NSWindow? {
        openNewWindow(with: Tab(url: url))
    }

}
