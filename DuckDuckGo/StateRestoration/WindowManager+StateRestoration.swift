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
import Common
import os.log

extension WindowsManager {

    @discardableResult class func restoreState(from coder: NSCoder, includePinnedTabs: Bool = true, includeWindows: Bool = true) throws -> WindowManagerStateRestoration {
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

        return state
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
        guard let window = openNewWindow(with: item.model, showWindow: !item.isMiniaturized, isMiniaturized: item.isMiniaturized) else { return }
        window.setContentSize(item.frame.size)
        window.setFrameOrigin(item.frame.origin)
    }

}

extension WindowControllersManager {

    @MainActor
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
            Logger.general.error("WindowsManager:initWithCoder: could not decode Restoration Array: \(String(describing: coder.error), privacy: .public)")
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

    @MainActor
    init(windowControllersManager: WindowControllersManager) {
        self.windows = windowControllersManager.mainWindowControllers
            .filter { $0.window?.isPopUpWindow == false }
            .sorted { (lhs, rhs) in
                let leftIndex = lhs.window?.orderedIndex ?? Int.min
                let rightIndex = rhs.window?.orderedIndex ?? Int.min
                return leftIndex < rightIndex
            }
            .compactMap { WindowRestorationItem(windowController: $0) }
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
        static let isMiniaturized = "isMiniaturized"

    }

    let model: TabCollectionViewModel
    let frame: NSRect
    let isMiniaturized: Bool

    @MainActor
    init?(windowController: MainWindowController) {
        guard !windowController.mainViewController.tabCollectionViewModel.isBurner else {
            // Don't persist burner windows
            return nil
        }

        self.frame = windowController.window!.frame
        self.model = windowController.mainViewController.tabCollectionViewModel
        self.isMiniaturized = windowController.window!.isMiniaturized
    }

    static var supportsSecureCoding: Bool { true }

    required init?(coder: NSCoder) {
        guard let model = coder.decodeObject(of: TabCollectionViewModel.self, forKey: NSSecureCodingKeys.model) else {
            Logger.general.error("WindowRestoration:initWithCoder: could not decode model object: \(String(describing: coder.error))")
            return nil
        }
        self.model = model
        self.frame = coder.decodeRect(forKey: NSSecureCodingKeys.frame)
        self.isMiniaturized = coder.decodeBool(forKey: NSSecureCodingKeys.isMiniaturized)
    }

    func encode(with coder: NSCoder) {
        coder.encode(frame, forKey: NSSecureCodingKeys.frame)
        coder.encode(model, forKey: NSSecureCodingKeys.model)
        coder.encode(isMiniaturized, forKey: NSSecureCodingKeys.isMiniaturized)
    }
}
