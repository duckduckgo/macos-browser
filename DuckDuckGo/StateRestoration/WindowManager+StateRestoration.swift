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
import DependencyInjection

extension WindowsManager {

    class func restoreState(from coder: SafeUnarchiver, /*dependencyProvider: WindowManagerStateRestoration.Dependencies,*/ includePinnedTabs: Bool = true, includeWindows: Bool = true) throws {
        let state = try coder.decodeObject(forKey: NSKeyedArchiveRootObjectKey) { coder in
            try WindowManagerStateRestoration(coder: coder)
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
        guard let window = openNewWindow(with: item.model, isBurner: false, showWindow: true) else { return }
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

#if swift(>=5.9)
@Injectable
#endif
@objc(WMState)
final class WindowManagerStateRestoration: NSObject, Injectable {

    typealias InjectedDependencies = WindowRestorationItem.Dependencies

    private enum NSSecureCodingKeys {
        static let controllers = "ctrls"
        static let keyWindowIndex = "key_idx"
        static let pinnedTabs = "pinned_tabs"
    }

    static var supportsSecureCoding: Bool { true }

    let windows: [WindowRestorationItem]
    let keyWindowIndex: Int?
    let pinnedTabs: TabCollection?

    @MainActor
    @available(*, deprecated, message: "use WindowManagerStateRestoration.make")
    init(coder: SafeUnarchiver) throws {
        let restorationArray = try coder.decodeArray(forKey: NSSecureCodingKeys.controllers) { coder in
            try WindowRestorationItem(coder: coder)
        }

        self.windows = restorationArray
        self.keyWindowIndex = coder.decodeIfPresent(at: NSSecureCodingKeys.keyWindowIndex)
        self.pinnedTabs = try? coder.decodeObject(forKey: NSSecureCodingKeys.pinnedTabs) { coder -> TabCollection in
            try TabCollection(coder: coder)
        }

        super.init()
    }

    @available(*, deprecated, message: "use WindowManagerStateRestoration.make")
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

#if swift(>=5.9)
@Injectable
#endif
@objc(WR)
final class WindowRestorationItem: NSObject, Injectable {

    typealias InjectedDependencies = TabCollectionViewModel.Dependencies

    private enum NSSecureCodingKeys {
        static let frame = "frame"
        static let model = "model"
    }

    let model: TabCollectionViewModel
    let frame: NSRect

    @available(*, deprecated, message: "use WindowRestorationItem.make")
    @MainActor
    init?(windowController: MainWindowController) {
        guard !windowController.mainViewController.tabCollectionViewModel.isBurner else {
            // Don't persist burner windows
            return nil
        }

        self.frame = windowController.window!.frame
        self.model = windowController.mainViewController.tabCollectionViewModel
    }

    static var supportsSecureCoding: Bool { true }

    @MainActor
    @available(*, deprecated, message: "use WindowRestorationItem.make")
    required init(coder: SafeUnarchiver) throws {
        let model = try coder.decodeObject(forKey: NSSecureCodingKeys.model) { coder in
            try TabCollectionViewModel(coder: coder)
        }
        self.model = model
        self.frame = .zero // coder.decodeRect(forKey: NSSecureCodingKeys.frame)
    }

    func encode(with coder: NSCoder) {
        coder.encode(frame, forKey: NSSecureCodingKeys.frame)
        coder.encode(model, forKey: NSSecureCodingKeys.model)
    }
}
