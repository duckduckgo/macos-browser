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
    case tab(selected: Bool)
    case popup(size: CGSize)
    case window(active: Bool)

    init(_ windowFeatures: WKWindowFeatures, shouldSelectNewTab: Bool = false) {
        if windowFeatures.toolbarsVisibility?.boolValue ?? false {
            let windowContentSize = NSSize(width: windowFeatures.width?.intValue ?? 1024,
                                           height: windowFeatures.height?.intValue ?? 752)
            self = .popup(size: windowContentSize)
        } else {
            self = .tab(selected: false)
        }
    }

}
