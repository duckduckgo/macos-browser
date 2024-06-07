//
//  NewWindowPolicy.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import Foundation
import WebKit

enum NewWindowPolicy {
    case tab(selected: Bool, burner: Bool, contextMenuInitiated: Bool = false)
    case popup(origin: NSPoint?, size: NSSize?)
    case window(active: Bool, burner: Bool)

    init(_ windowFeatures: WKWindowFeatures, shouldSelectNewTab: Bool = false, isBurner: Bool, contextMenuInitiated: Bool = false) {
        if windowFeatures.toolbarsVisibility?.boolValue == true {
            self = .tab(selected: shouldSelectNewTab,
                        burner: isBurner,
                        contextMenuInitiated: contextMenuInitiated)
        } else if windowFeatures.width != nil {
            self = .popup(origin: windowFeatures.origin, size: windowFeatures.size)

        } else
        // This is a temporary fix for macOS 14.1 WKWindowFeatures being empty when opening a new regular tab
        // Instead of defaulting to window policy, we default to tab policy, and allow popups in some limited scenarios.
        // See https://app.asana.com/0/1177771139624306/1205690527704551/f.
        if #available(macOS 14.1, *),
           windowFeatures.statusBarVisibility == nil && windowFeatures.menuBarVisibility == nil {
            self = .tab(selected: shouldSelectNewTab, burner: isBurner, contextMenuInitiated: contextMenuInitiated)

        } else {
            self = .window(active: true, burner: isBurner)
        }
    }

    var isTab: Bool {
        if case .tab = self { return true }
        return false
    }
    var isSelectedTab: Bool {
        if case .tab(selected: true, burner: _, contextMenuInitiated: _) = self { return true }
        return false
    }

    /**
     * Replaces `.tab` with `.window` when user prefers windows over tabs.
     */
    func preferringTabsToWindows(_ prefersTabsToWindows: Bool) -> NewWindowPolicy {
        guard case .tab(_, let isBurner, contextMenuInitiated: false) = self, !prefersTabsToWindows else {
            return self
        }
        return .window(active: true, burner: isBurner)
    }

    /**
     * Forces selecting a tab if `true` is passed as argument.
     */
    func preferringSelectedTabs(_ prefersSelectedTabs: Bool) -> NewWindowPolicy {
        guard case .tab(selected: false, burner: let isBurner, contextMenuInitiated: let contextMenuInitiated) = self, prefersSelectedTabs else {
            return self
        }
        return .tab(selected: true, burner: isBurner, contextMenuInitiated: contextMenuInitiated)
    }

}

extension WKWindowFeatures {

    var origin: NSPoint? {
        guard x != nil || y != nil else { return nil }
        return NSPoint(x: x?.intValue ?? 0, y: y?.intValue ?? 0)
    }

    var size: NSSize? {
        guard width != nil || height != nil else { return nil }
        return NSSize(width: self.width?.intValue ?? 0, height: self.height?.intValue ?? 0)
    }

}
