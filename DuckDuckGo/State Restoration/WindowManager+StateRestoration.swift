//
//  WindowManagerStateRestoration.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

extension WindowsManager {

    class func restoreState(from coder: NSCoder) throws {
        guard let state = coder.decodeObject(of: WindowManagerStateRestoration.self,
                                             forKey: NSKeyedArchiveRootObjectKey) else {
            throw coder.error ?? NSError(domain: "WindowsManagerStateRestoration", code: -1, userInfo: nil)
        }

        self.restoreWindows(from: state)
    }

    private class func restoreWindows(from state: WindowManagerStateRestoration) {
        var keyWindow: NSWindow?
        for (idx, item) in state.windows.enumerated() {
            let window = self.openNewWindow(with: item.model)
            window.setContentSize(item.frame.size)
            window.setFrameOrigin(item.frame.origin)

            if idx == state.keyWindowIndex {
                keyWindow = window
            }
        }
        keyWindow?.makeKeyAndOrderFront(self)
    }

}

extension WindowControllersManager {

    func encodeState(with coder: NSCoder) {
        coder.encode(WindowManagerStateRestoration(windowControllersManager: self),
                     forKey: NSKeyedArchiveRootObjectKey)
    }

}

@objc(WMState)
final class WindowManagerStateRestoration: NSObject, NSSecureCoding {
    private enum NSCodingKeys {
        static let controllers = "ctrls"
        static let keyWindowIndex = "key_idx"
    }

    static var supportsSecureCoding: Bool { true }

    let windows: [WindowRestorationItem]
    let keyWindowIndex: Int?

    init?(coder: NSCoder) {
        guard let restorationArray = coder.decodeObject(of: [NSArray.self, WindowRestorationItem.self],
                                             forKey: NSCodingKeys.controllers) as? [WindowRestorationItem] else {
            os_log("WindowsManager:initWithCoder: could not decode Restoration Array: %s", type: .error,
                   String(describing: coder.error))
            return nil
        }
        self.windows = restorationArray
        self.keyWindowIndex = coder.containsValue(forKey: NSCodingKeys.keyWindowIndex)
            ? coder.decodeInteger(forKey: NSCodingKeys.keyWindowIndex)
            : nil

        super.init()
    }

    init(windowControllersManager: WindowControllersManager) {
        self.windows = windowControllersManager.mainWindowControllers
            .map(WindowRestorationItem.init(windowController:))
        self.keyWindowIndex = windowControllersManager.lastKeyMainWindowController.flatMap {
            windowControllersManager.mainWindowControllers.firstIndex(of: $0)
        }
    }

    func encode(with coder: NSCoder) {
        #warning("Skip Private Windows coding")

        coder.encode(windows as NSArray, forKey: NSCodingKeys.controllers)
        keyWindowIndex.map(coder.encode(forKey: NSCodingKeys.keyWindowIndex))
    }
}

@objc(WR)
final class WindowRestorationItem: NSObject, NSSecureCoding {
    private enum NSCodingKeys {
        static let frame = "frame"
        static let model = "model"

    }

    let model: TabCollectionViewModel
    let frame: NSRect

    init(windowController: MainWindowController) {
        self.frame = windowController.window!.frame
        self.model = windowController.mainViewController!.tabCollectionViewModel
    }

    static var supportsSecureCoding: Bool { true }

    required init?(coder: NSCoder) {
        guard let model = coder.decodeObject(of: TabCollectionViewModel.self, forKey: NSCodingKeys.model) else {
            os_log("WindowRestoration:initWithCoder: could not decode model object: %s", type: .error, String(describing: coder.error))
            return nil
        }
        self.model = model
        self.frame = coder.decodeRect(forKey: NSCodingKeys.frame)
    }

    func encode(with coder: NSCoder) {
        coder.encode(frame, forKey: NSCodingKeys.frame)
        coder.encode(model, forKey: NSCodingKeys.model)
    }
}
