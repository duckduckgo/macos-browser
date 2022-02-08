//
//  Feedback.swift
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

import Foundation
import QuartzCore

struct Feedback {

    let category: Category
    let subcategory: Subcategory?
    let comment: String?

    init?(category: Category, subcategory: Subcategory?, comment: String?) {
        if category == .websiteBreakage && subcategory == nil {
            return nil
        }
        if category != .websiteBreakage && comment?.isEmpty ?? true {
            return nil
        }
        self.category = category
        self.subcategory = subcategory
        self.comment = comment
    }

    enum Category {
        case websiteBreakage
        case bug
        case featureRequest
        case other

        var subcategories: [Subcategory] {
            switch self {
            case .bug, .featureRequest, .other:
                return []
            case .websiteBreakage:
                return Subcategory.allCases
            }
        }

        var asanaId: String? {
            switch self {
            case .bug: return "1199184518165816"
            case .featureRequest: return "1199184518165815"
            case .other: return "1200574389728916"
            case .websiteBreakage: return nil
            }
        }
    }

    enum Subcategory: CaseIterable {
        case theSiteAskedToDisable
        case cantSignIn
        case linksDontWork
        case imagesDidntLoad
        case videoDidntPlay
        case contentIsMissing
        case commentsDidntLoad
        case somethingElse
    }

}
