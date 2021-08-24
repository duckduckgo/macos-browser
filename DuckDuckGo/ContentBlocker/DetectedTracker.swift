//
//  DetectedTracker.swift
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
import TrackerRadarKit

// Populated with relevant info at the point of detection.
struct DetectedTracker: Encodable {

    let url: String
    let knownTracker: KnownTracker?
    let entity: Entity?
    let blocked: Bool

    init(url: String, knownTracker: KnownTracker?, entity: Entity?, blocked: Bool) {
        self.url = url
        self.knownTracker = knownTracker
        self.entity = entity
        self.blocked = blocked
    }

    var domain: String? {
        return URL(string: url)?.host
    }

    var networkNameForDisplay: String {
        return entity?.displayName ?? domain ?? url
    }

}

extension DetectedTracker: Hashable, Equatable {

    static func == (lhs: DetectedTracker, rhs: DetectedTracker) -> Bool {
        return ((lhs.entity != nil || rhs.entity != nil) && lhs.entity?.displayName == rhs.entity?.displayName)
            && lhs.domain ?? "" == rhs.domain ?? ""
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.entity?.displayName)
        hasher.combine(self.domain)
    }

}
