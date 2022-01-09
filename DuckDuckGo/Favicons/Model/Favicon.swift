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
        case noImage = 0
        case tiny = 1
        case small = 32
        case medium = 132
        case large = 264
        case huge = 2048

        init(imageSize: CGSize?) {
            guard let imageSize = imageSize else {
                self = .noImage
                return
            }
            let longestSide = max(imageSize.width, imageSize.height)
            switch longestSide {
            case 0: self = .noImage
            case 1..<Self.small.rawValue:  self = .tiny
            case Self.small.rawValue..<Self.medium.rawValue: self = .small
            case Self.medium.rawValue..<Self.large.rawValue: self = .medium
            case Self.large.rawValue..<Self.huge.rawValue: self = .large
            default: self = .huge
            }
        }
    }

    init(identifier: UUID, url: URL, image: NSImage?, relationString: String, documentUrl: URL, dateCreated: Date) {
        self.init(identifier: identifier,
                  url: url, image: image,
                  relation: Relation(relationString: relationString),
                  documentUrl: documentUrl,
                  dateCreated: dateCreated)
    }

    init(identifier: UUID, url: URL, image: NSImage?, relation: Relation, documentUrl: URL, dateCreated: Date) {

        // Avoid storing or using of non-valid or huge images
        if let image = image, image.isValid {
            let sizeCategory = SizeCategory(imageSize: image.size)
            if sizeCategory == .huge || sizeCategory == .noImage {
                self.image = nil
            } else {
                self.image = image
            }
        } else {
            self.image = nil
        }

        self.identifier = identifier
        self.url = url
        self.relation = relation
        self.sizeCategory = SizeCategory(imageSize: self.image?.size)
        self.documentUrl = documentUrl
        self.dateCreated = dateCreated
    }

    let identifier: UUID
    let url: URL
    let image: NSImage?
    let relation: Relation
    let sizeCategory: SizeCategory
    let documentUrl: URL
    let dateCreated: Date

    var longestSide: CGFloat {
        guard let image = image else {
            return 0
        }

        return max(image.size.width, image.size.height)
    }
}
