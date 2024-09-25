//
//  NavigationActionExtension.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Navigation

extension NavigationAction {

    var isUserEnteredUrl: Bool {
        if #available(macOS 12.0, *),
           case .other = navigationType,
           case .user = request.attribution {
            return true
        } else if case .custom(.userEnteredUrl) = navigationType {
            return true
        }
        return false
    }

    var isCustom: Bool {
        if case .custom = self.navigationType {
            return true
        }
        return false
    }

}

extension CustomNavigationType {
    static let userEnteredUrl = CustomNavigationType(rawValue: "userEnteredUrl")
    static let loadedByStateRestoration = CustomNavigationType(rawValue: "loadedByStateRestoration")
    static let appOpenUrl = CustomNavigationType(rawValue: "appOpenUrl")
    static let historyEntry = CustomNavigationType(rawValue: "historyEntry")
    static let bookmark = CustomNavigationType(rawValue: "bookmark")
    static let ui = CustomNavigationType(rawValue: "ui")
    static let link = CustomNavigationType(rawValue: "link")
    static let webViewUpdated = CustomNavigationType(rawValue: "webViewUpdated")
    static let userRequestedPageDownload = CustomNavigationType(rawValue: "userRequestedPageDownload")
}
