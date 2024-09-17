//
//  DownloadListItem.swift
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

import Common
import Foundation
import UniformTypeIdentifiers

struct DownloadListItem: Equatable {

    let identifier: UUID
    let added: Date
    var modified: Date

    let downloadURL: URL
    let websiteURL: URL?
    var fileName: String {
        didSet {
            guard fileName != oldValue else { return }
            modified = Date()
        }
    }

    var progress: Progress? {
        didSet {
            guard progress !== oldValue else { return }
            modified = Date()
        }
    }

    let fireWindowSession: FireWindowSessionRef?
    var isBurner: Bool {
        fireWindowSession != nil
    }

    /// final download destination url, will match actual file url when download is finished
    var destinationURL: URL? {
        didSet {
            guard destinationURL != oldValue else { return }
            modified = Date()
        }
    }

    var destinationFileBookmarkData: Data? {
        didSet {
            guard destinationFileBookmarkData != oldValue else { return }
            modified = Date()
        }
    }

    /// temp download file URL (`.duckload`)
    var tempURL: URL? {
        didSet {
            guard tempURL != oldValue else { return }
            modified = Date()
        }
    }

    var tempFileBookmarkData: Data? {
        didSet {
            guard tempFileBookmarkData != oldValue else { return }
            modified = Date()
        }
    }

    var error: FileDownloadError? {
        didSet {
            guard error != oldValue else { return }
            modified = Date()
        }
    }

}
