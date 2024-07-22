//
//  BookmarksMetrics.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import PixelKit

protocol BookmarksMetricsProtocol {
    func fireSortButtonClicked(origin: BookmarkOperationOrigin)
    func fireSortButtonDismissed(origin: BookmarkOperationOrigin)
    func fireSortByName(origin: BookmarkOperationOrigin)
    func fireSearchExecuted(origin: BookmarkOperationOrigin)
    func fireSearchResultClicked(origin: BookmarkOperationOrigin)
}

enum BookmarkOperationOrigin: String {
    case panel
    case manager
}

struct BookmarksMetrics: BookmarksMetricsProtocol {
    private let pixelKit = PixelKit.shared

    func fireSortButtonClicked(origin: BookmarkOperationOrigin) {
        pixelKit?.fire(GeneralPixel.bookmarksSortButtonClicked(origin: origin.rawValue))
    }
    
    func fireSortButtonDismissed(origin: BookmarkOperationOrigin) {
        pixelKit?.fire(GeneralPixel.bookmarksSortButtonDismissed(origin: origin.rawValue))
    }
    
    func fireSortByName(origin: BookmarkOperationOrigin) {
        pixelKit?.fire(GeneralPixel.bookmarksSortByName(origin: origin.rawValue))
    }
    
    func fireSearchExecuted(origin: BookmarkOperationOrigin) {
        pixelKit?.fire(GeneralPixel.bookmarksSearchExecuted(origin: origin.rawValue))
    }
    
    func fireSearchResultClicked(origin: BookmarkOperationOrigin) {
        pixelKit?.fire(GeneralPixel.bookmarksSearchResultClicked(origin: origin.rawValue))
    }
}
