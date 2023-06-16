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

extension WindowManager {

    func restoreState(from coder: NSCoder, dependencyProvider: TabCollectionViewModel.DependencyProvider, includePinnedTabs: Bool = true, includeWindows: Bool = true) throws {
        let state = try coder.decode(at: NSKeyedArchiveRootObjectKey) { coder in
            try WindowManagerStateRestoration(dependencyProvider: dependencyProvider, coder: coder)
        }

        if let pinnedTabsCollection = state.pinnedTabs {
            restorePinnedTabs(pinnedTabsCollection)
        }
        if includeWindows {
            restoreWindows(from: state)
        }
    }

    private func restoreWindows(from state: WindowManagerStateRestoration) {
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

    private func setUpWindow(from item: WindowRestorationItem) {
        guard let window = openNewWindow(with: item.model, isBurner: false, showWindow: true) else { return }
        window.setContentSize(item.frame.size)
        window.setFrameOrigin(item.frame.origin)
    }

    @MainActor
    func encodeState(with coder: NSCoder) {
        coder.encode(WindowManagerStateRestoration(windowManager: self),
                     forKey: NSKeyedArchiveRootObjectKey)
    }

    func restorePinnedTabs(_ collection: TabCollection) {
        pinnedTabsManager.setUp(with: collection)
    }

}

struct WindowManagerStateRestoration: NSSecureEncodable {

    private enum NSSecureCodingKeys {
        static let controllers = "ctrls"
        static let keyWindowIndex = "key_idx"
        static let pinnedTabs = "pinned_tabs"
    }

    static var supportsSecureCoding: Bool { true }

    let windows: [WindowRestorationItem]
    let keyWindowIndex: Int?
    let pinnedTabs: TabCollection?

    static var className: String? { "WMState" }

    @MainActor
    init(dependencyProvider: TabCollectionViewModel.DependencyProvider, coder: NSCoder) throws {
        let restorationArray = try coder.decodeArray(at: NSSecureCodingKeys.controllers) { coder in
            try WindowRestorationItem(dependencyProvider: dependencyProvider, coder: coder)
        }

        self.windows = restorationArray
        self.keyWindowIndex = coder.decodeIfPresent(at: NSSecureCodingKeys.keyWindowIndex)
        self.pinnedTabs = try? (coder.decode(at: NSSecureCodingKeys.pinnedTabs) { coder -> TabCollection in
            try TabCollection(coder: coder, dependencyProvider: dependencyProvider)
        } as TabCollection)
    }

    @MainActor
    init(windowManager: WindowManager) {
        self.windows = windowManager.mainWindowControllers
            .filter { $0.window?.isPopUpWindow == false }
            .sorted { (lhs, rhs) in
                let leftIndex = lhs.window?.orderedIndex ?? Int.min
                let rightIndex = rhs.window?.orderedIndex ?? Int.min
                return leftIndex < rightIndex
            }
            .compactMap { WindowRestorationItem(windowController: $0) }
        self.keyWindowIndex = windowManager.lastKeyMainWindowController.flatMap {
            windowManager.mainWindowControllers.firstIndex(of: $0)
        }

        self.pinnedTabs = windowManager.pinnedTabsManager.tabCollection
    }

    func encode(with coder: NSCoder) {
        coder.encode(windows, forKey: NSSecureCodingKeys.controllers)
        keyWindowIndex.map(coder.encode(forKey: NSSecureCodingKeys.keyWindowIndex))
        pinnedTabs.map(coder.encode(forKey: NSSecureCodingKeys.pinnedTabs))
    }
}

struct WindowRestorationItem: NSSecureEncodable {

    private enum NSSecureCodingKeys {
        static let frame = "frame"
        static let model = "model"
    }

    let model: TabCollectionViewModel
    let frame: NSRect

    @MainActor
    init?(windowController: MainWindowController) {
        guard !windowController.mainViewController.tabCollectionViewModel.isBurner else {
            // Don't persist burner windows
            return nil
        }

        self.frame = windowController.window!.frame
        self.model = windowController.mainViewController.tabCollectionViewModel
    }

    static var className: String? { "WR" }

    @MainActor
    init(dependencyProvider: TabCollectionViewModel.DependencyProvider, coder: NSCoder) throws {
        let model = try coder.decode(at: NSSecureCodingKeys.model) { coder in
            try TabCollectionViewModel(coder: coder, dependencyProvider: dependencyProvider)
        }
        self.model = model
        self.frame = coder.decodeRect(forKey: NSSecureCodingKeys.frame)
    }

    func encode(with coder: NSCoder) {
        coder.encode(frame, forKey: NSSecureCodingKeys.frame)
        coder.encode(model, forKey: NSSecureCodingKeys.model)
    }

}
