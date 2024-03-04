//
//  BackForwardListItemViewModel.swift
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
import History

final class BackForwardListItemViewModel {

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
        switch backForwardListItem.kind {
        case .url(let url):
            if url == .newtab {
                return UserText.tabHomeTitle
            }

            var title = backForwardListItem.title

            if title == nil || (title?.isEmpty ?? false) {
                title = historyCoordinating.title(for: url)
            }

            return (title ?? url.host ?? url.absoluteString).truncated(length: MainMenu.Constants.maxTitleLength)

        case .goBackToClose(let url):
            if let title = backForwardListItem.title ?? url?.absoluteString, !title.isEmpty {
                return String(format: UserText.closeAndReturnToParentFormat, title.truncated(length: MainMenu.Constants.maxTitleLength))
            } else {
                return UserText.closeAndReturnToParent
            }
        }
    }

    @MainActor(unsafe)
    var image: NSImage? {
        if backForwardListItem.url == .newtab {
            return .homeFavicon
        }

        if backForwardListItem.url?.isDuckPlayer == true {
            return .duckPlayer
        }

        if let url = backForwardListItem.url,
           let favicon = faviconManagement.getCachedFavicon(for: url, sizeCategory: .small),
           let image = favicon.image?.resizedToFaviconSize() {
            return image
        }

        return .globeMulticolor16
    }

    var state: NSControl.StateValue {
        isCurrentItem ? .on : .off
    }

}
