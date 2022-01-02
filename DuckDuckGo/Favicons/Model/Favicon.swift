//
//  Favicon.swift
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

import Cocoa
import Foundation

struct Favicon {

    enum Relation: Int {
        case favicon = 2
        case icon = 1
        case other = 0

        init(relationString: String) {
            if relationString == "favicon" {
                self = .favicon
                return
            }
            if relationString.contains("icon") {
                self = .icon
                return
            }
            self = .other
        }
    }

    enum SizeCategory: CGFloat {
        case tiny = 0
        case small = 32
        case medium = 132
        case large = 264

        init(imageSize: CGSize) {
            let maxSide = max(imageSize.width, imageSize.height)
            switch maxSide {
            case 0..<Self.small.rawValue:  self = .tiny
            case Self.small.rawValue..<Self.medium.rawValue: self = .small
            case Self.medium.rawValue..<Self.large.rawValue: self = .medium
            default: self = .large
            }
        }
    }

    init(identifier: UUID, url: URL, image: NSImage, relationString: String, documentUrl: URL, dateCreated: Date) {
        self.init(identifier: identifier,
                  url: url, image: image,
                  relation: Relation(relationString: relationString),
                  documentUrl: documentUrl,
                  dateCreated: dateCreated)
    }

    init(identifier: UUID, url: URL, image: NSImage, relation: Relation, documentUrl: URL, dateCreated: Date) {
        self.identifier = identifier
        self.url = url
        self.image = image
        self.relation = relation
        sizeCategory = SizeCategory(imageSize: image.size)
        self.documentUrl = documentUrl
        self.dateCreated = dateCreated
    }

    let identifier: UUID
    let url: URL
    let image: NSImage
    let relation: Relation
    let sizeCategory: SizeCategory
    let documentUrl: URL
    let dateCreated: Date

}
