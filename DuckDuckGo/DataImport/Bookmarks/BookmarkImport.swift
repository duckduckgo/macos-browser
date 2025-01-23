//
//  BookmarkImport.swift
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

import Foundation
import BrowserServicesKit

enum BookmarkImportSource: Equatable {
    case duckduckgoWebKit
    case thirdPartyBrowser(DataImport.Source)

    var importSourceName: String {
        switch self {
        case .duckduckgoWebKit: return UserText.importBookmarksHTML
        case .thirdPartyBrowser(let source): return source.importSourceName
        }
    }
}

protocol BookmarkImporter {

    func importBookmarks(_ bookmarks: ImportedBookmarks, source: BookmarkImportSource) -> BookmarksImportSummary

}
