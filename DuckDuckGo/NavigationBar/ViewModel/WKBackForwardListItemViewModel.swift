//
//  ViewModel.swift
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

class WKBackForwardListItemViewModel {

    private let backForwardListItem: WKBackForwardListItem
    private let faviconService: FaviconService

    init(backForwardListItem: WKBackForwardListItem, faviconService: FaviconService) {
        self.backForwardListItem = backForwardListItem
        self.faviconService = faviconService
    }

    var title: String {
        if backForwardListItem.url == URL.emptyPage {
            return UserText.tabHomeTitle
        }

        return backForwardListItem.title ??
            backForwardListItem.url.host ??
            backForwardListItem.url.absoluteString
    }

    var image: NSImage? {
        if backForwardListItem.url == URL.emptyPage {
            return NSImage(named: "HomeFavicon")
        }

        if let host = backForwardListItem.url.host, let favicon = faviconService.getCachedFavicon(for: host, mustBeFromUserScript: false) {
            favicon.size = NSSize.faviconSize
            return favicon
        }

        return NSImage(named: "DefaultFavicon")
    }

}
