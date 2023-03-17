//
//  WKBackForwardListItemViewModel.swift
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
import WebKit

final class WKBackForwardListItemViewModel {

    private let backForwardListItem: BackForwardListItem
    private let faviconManagement: FaviconManagement
    private let historyCoordinating: HistoryCoordinating
    private let isCurrentItem: Bool

    init(backForwardListItem: BackForwardListItem,
         faviconManagement: FaviconManagement,
         historyCoordinating: HistoryCoordinating,
         isCurrentItem: Bool) {
        self.backForwardListItem = backForwardListItem
        self.faviconManagement = faviconManagement
        self.historyCoordinating = historyCoordinating
        self.isCurrentItem = isCurrentItem
    }

    var title: String {
        switch backForwardListItem {
        case .backForwardListItem(let item):
            if item.url == .homePage {
                return UserText.tabHomeTitle
            }

            var title = item.title

            if title == nil || (title?.isEmpty ?? false) {
                title = historyCoordinating.title(for: item.url)
            }

            return title ??
                item.url.host ??
                item.url.absoluteString

        case .goBackToCloseItem(parentTab: let tab):
            if let title = tab.title,
               !title.isEmpty {
                return String(format: UserText.closeAndReturnToParentFormat, title)
            } else {
                return UserText.closeAndReturnToParent
            }
        case .error:
            return UserText.tabErrorTitle
        }
    }

    var image: NSImage? {
        if case .error = backForwardListItem {
            return nil
        }

        if backForwardListItem.url == .homePage {
            return NSImage(named: "HomeFavicon")
        }

        if backForwardListItem.url?.isDuckPlayer == true {
            return .duckPlayer
        }

        if let url = backForwardListItem.url,
           let favicon = faviconManagement.getCachedFavicon(for: url, sizeCategory: .small),
           let image = favicon.image?.resizedToFaviconSize() {
            return image
        }

        return NSImage(named: "DefaultFavicon")
    }

    var state: NSControl.StateValue {
        if case .goBackToCloseItem = backForwardListItem {
            return .off
        }

        return isCurrentItem ? .on : .off
    }

    var isGoBackToCloseItem: Bool {
        if case .goBackToCloseItem = backForwardListItem {
            return true
        }

        return false
    }

}
