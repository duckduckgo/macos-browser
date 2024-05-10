//
//  VisitViewModel.swift
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

import Cocoa
import History

final class VisitViewModel {

    let visit: Visit
    let faviconManager: FaviconManagement

    init(visit: Visit,
         faviconManager: FaviconManagement = FaviconManager.shared) {
        self.visit = visit
        self.faviconManager = faviconManager
    }

    var title: String {
        guard let historyEntry = visit.historyEntry else {
            assertionFailure("History entry already deallocated")
            return "-"
        }

        return historyEntry.title ?? historyEntry.url.absoluteString
    }

    var titleTruncated: String {
        title.truncated(length: MainMenu.Constants.maxTitleLength)
    }

    @MainActor(unsafe)
    var smallFaviconImage: NSImage? {
        guard let historyEntry = visit.historyEntry else {
            assertionFailure("History entry already deallocated")
            return nil
        }

        if historyEntry.url.isDuckPlayer {
            return .duckPlayer
        }

        return faviconManager.getCachedFavicon(for: historyEntry.url, sizeCategory: .small)?.image
    }

}
