//
//  BackForwardListItem.swift
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

import WebKit

enum BackForwardListItem: Equatable {
    case backForwardListItem(WKBackForwardListItem)
    case goBackToCloseItem(parentTab: Tab)
    case error

    var url: URL? {
        switch self {
        case .backForwardListItem(let item):
            return item.url
        case .goBackToCloseItem(parentTab: let tab):
            return tab.content.userEditableUrl
        case .error:
            return nil
        }
    }

}
