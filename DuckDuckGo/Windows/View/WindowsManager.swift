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
    static public var shared = WindowsManager()

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

// MARK: - State Restoration

extension WindowsManager {

    func restoreState(from coder: NSCoder) throws {
        guard let state = coder.decodeObject(of: WindowManagerStateRestoration.self,
                                             forKey: NSKeyedArchiveRootObjectKey) else {
            throw coder.error ?? NSError(domain: "WindowsManagerStateRestoration", code: -1, userInfo: nil)
        }

        state.restoreWindows(into: self)
    }

}

extension WindowControllersManager {

    func encodeState(with coder: NSCoder) {
        coder.encode(WindowManagerStateRestoration(windowControllersManager: self),
                     forKey: NSKeyedArchiveRootObjectKey)
    }

}

@objc(WMState)
private final class WindowManagerStateRestoration: NSObject, NSSecureCoding {
    private enum NSCodingKeys {
        static let controllers = "ctrls"
        static let keyWindowIndex = "key_idx"
    }

    static var supportsSecureCoding: Bool { true }

    private let windows: [WindowRestorationItem]
    private let keyWindowIndex: Int?

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

    func restoreWindows(into windowManager: WindowsManager) {
        var keyWindow: NSWindow?
        for (idx, item) in windows.enumerated() {
            let window = windowManager.openNewWindow(with: item.model, at: .origin(item.frame.origin), with: item.frame.size)
            if idx == keyWindowIndex {
                keyWindow = window
            }
        }
        keyWindow?.makeKey()
    }

    init(windowControllersManager: WindowControllersManager) {
        self.windows = windowControllersManager.mainWindowControllers
            .map(WindowRestorationItem.init(windowController:))
        self.keyWindowIndex = windowControllersManager.mainWindowControllers
            .firstIndex(where: { $0.window!.isKeyWindow })
    }

    func encode(with coder: NSCoder) {
        #warning("Skip Private Windows coding")

        coder.encode(windows as NSArray, forKey: NSCodingKeys.controllers)
        if let keyWindowIndex = keyWindowIndex {
            coder.encode(keyWindowIndex, forKey: NSCodingKeys.keyWindowIndex)
        }
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
        self.model = windowController.tabCollectionViewModel
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
