//
//  WindowManager+StateRestoration.swift
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

    class func restoreState(from coder: NSCoder, includePinnedTabs: Bool = true, includeWindows: Bool = true) throws {
        guard let state = coder.decodeObject(of: WindowManagerStateRestoration.self,
                                             forKey: NSKeyedArchiveRootObjectKey) else {
            throw coder.error ?? NSError(domain: "WindowsManagerStateRestoration", code: -1, userInfo: nil)
        }

        if let pinnedTabsCollection = state.pinnedTabs {
            WindowControllersManager.shared.restorePinnedTabs(pinnedTabsCollection)
        }
        if includeWindows {
            restoreWindows(from: state)
        }
    }

    private class func restoreWindows(from state: WindowManagerStateRestoration) {
        for item in state.windows.reversed() {
            setUpWindow(from: item)
        }

        if let idx = state.keyWindowIndex {
            state.windows[safe: idx]?.model.setUpLazyLoadingIfNeeded()
        }

        if !state.windows.isEmpty {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private class func setUpWindow(from item: WindowRestorationItem) {
        //TODO!
        guard let window = openNewWindow(with: item.model, isDisposable: false, showWindow: true) else { return }
        window.setContentSize(item.frame.size)
        window.setFrameOrigin(item.frame.origin)
    }

}

extension WindowControllersManager {

    func encodeState(with coder: NSCoder) {
        coder.encode(WindowManagerStateRestoration(windowControllersManager: self),
                     forKey: NSKeyedArchiveRootObjectKey)
    }

    func restorePinnedTabs(_ collection: TabCollection) {
        pinnedTabsManager.setUp(with: collection)
    }

}

@objc(WMState)
final class WindowManagerStateRestoration: NSObject, NSSecureCoding {
    private enum NSSecureCodingKeys {
        static let controllers = "ctrls"
        static let keyWindowIndex = "key_idx"
        static let pinnedTabs = "pinned_tabs"
    }

    static var supportsSecureCoding: Bool { true }

    let windows: [WindowRestorationItem]
    let keyWindowIndex: Int?
    let pinnedTabs: TabCollection?

    init?(coder: NSCoder) {
        guard let restorationArray = coder.decodeObject(of: [NSArray.self, WindowRestorationItem.self],
                                             forKey: NSSecureCodingKeys.controllers) as? [WindowRestorationItem] else {
            os_log("WindowsManager:initWithCoder: could not decode Restoration Array: %s", type: .error,
                   String(describing: coder.error))
            return nil
        }
        self.windows = restorationArray
        self.keyWindowIndex = coder.containsValue(forKey: NSSecureCodingKeys.keyWindowIndex)
            ? coder.decodeInteger(forKey: NSSecureCodingKeys.keyWindowIndex)
            : nil

        self.pinnedTabs = coder.containsValue(forKey: NSSecureCodingKeys.pinnedTabs)
            ? coder.decodeObject(of: TabCollection.self, forKey: NSSecureCodingKeys.pinnedTabs)
            : nil

        super.init()
    }

    init(windowControllersManager: WindowControllersManager) {
        self.windows = windowControllersManager.mainWindowControllers
            .filter { $0.window?.isPopUpWindow == false }
            .sorted { (lhs, rhs) in
                let leftIndex = lhs.window?.orderedIndex ?? Int.min
                let rightIndex = rhs.window?.orderedIndex ?? Int.min
                return leftIndex < rightIndex
            }
            .map(WindowRestorationItem.init(windowController:))
        self.keyWindowIndex = windowControllersManager.lastKeyMainWindowController.flatMap {
            windowControllersManager.mainWindowControllers.firstIndex(of: $0)
        }

        self.pinnedTabs = windowControllersManager.pinnedTabsManager.tabCollection
    }

    func encode(with coder: NSCoder) {
        coder.encode(windows as NSArray, forKey: NSSecureCodingKeys.controllers)
        keyWindowIndex.map(coder.encode(forKey: NSSecureCodingKeys.keyWindowIndex))
        coder.encode(pinnedTabs, forKey: NSSecureCodingKeys.pinnedTabs)
    }
}

@objc(WR)
final class WindowRestorationItem: NSObject, NSSecureCoding {
    private enum NSSecureCodingKeys {
        static let frame = "frame"
        static let model = "model"

    }

    let model: TabCollectionViewModel
    let frame: NSRect

    init(windowController: MainWindowController) {
        self.frame = windowController.window!.frame
        self.model = windowController.mainViewController.tabCollectionViewModel
    }

    static var supportsSecureCoding: Bool { true }

    required init?(coder: NSCoder) {
        guard let model = coder.decodeObject(of: TabCollectionViewModel.self, forKey: NSSecureCodingKeys.model) else {
            os_log("WindowRestoration:initWithCoder: could not decode model object: %s", type: .error, String(describing: coder.error))
            return nil
        }
        self.model = model
        self.frame = coder.decodeRect(forKey: NSSecureCodingKeys.frame)
    }

    func encode(with coder: NSCoder) {
        coder.encode(frame, forKey: NSSecureCodingKeys.frame)
        coder.encode(model, forKey: NSSecureCodingKeys.model)
    }
}
