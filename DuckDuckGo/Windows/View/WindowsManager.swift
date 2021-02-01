//
//  WindowManager.swift
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

class WindowsManager {

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
    class func openNewWindow(with tabCollectionViewModel: TabCollectionViewModel? = nil, droppingPoint: NSPoint? = nil) -> NSWindow {
        let mainWindowController = MainWindowController(tabCollectionViewModel: tabCollectionViewModel)

        if let droppingPoint = droppingPoint {
            mainWindowController.window?.setFrameOrigin(droppingPoint: droppingPoint)
        }
        mainWindowController.showWindow(self)

        return mainWindowController.window!
    }

    class func openNewWindow(with tab: Tab, droppingPoint: NSPoint? = nil) {
        let tabCollection = TabCollection(tabs: [tab])
        openNewWindow(with: TabCollectionViewModel(tabCollection: tabCollection))
    }

    class func openNewWindow(with initialUrl: URL) {
        openNewWindow(with: Tab(url: initialUrl))
    }

}
