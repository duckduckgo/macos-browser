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

import Foundation

struct DownloadListItem: Equatable {

    let identifier: UUID
    let added: Date
    var modified: Date

    let url: URL
    let websiteURL: URL?

    var progress: Progress?

    let isBurner: Bool

    var fileType: UTType? {
        didSet {
            guard fileType != oldValue else { return }
            modified = Date()
        }
    }

    var destinationURL: URL? {
        didSet {
            guard destinationURL != oldValue else { return }
            modified = Date()
        }
    }

    var tempURL: URL? {
        didSet {
            guard tempURL != oldValue else { return }
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
