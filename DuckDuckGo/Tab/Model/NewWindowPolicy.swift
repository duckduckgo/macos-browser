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
    case tab(selected: Bool, burner: Bool)
    case popup(origin: NSPoint?, size: NSSize?)
    case window(active: Bool, burner: Bool)

    init(_ windowFeatures: WKWindowFeatures, shouldSelectNewTab: Bool = false, isBurner: Bool) {
        if windowFeatures.toolbarsVisibility?.boolValue == true {
            self = .tab(selected: shouldSelectNewTab,
                        burner: isBurner)
        } else if windowFeatures.width != nil {
            self = .popup(origin: windowFeatures.origin, size: windowFeatures.size)
        } else {
            self = .window(active: true, burner: isBurner)
        }
    }

    var isTab: Bool {
        if case .tab = self { return true }
        return false
    }
    var isSelectedTab: Bool {
        if case .tab(selected: true, burner: _) = self { return true }
        return false
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
