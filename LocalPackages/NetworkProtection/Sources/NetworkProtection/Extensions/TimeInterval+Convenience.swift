//
//  TimeInterval+Convenience.swift
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

public extension TimeInterval {
    static let day = days(1)

    static func seconds(_ amount: Int) -> TimeInterval {
        TimeInterval(amount)
    }

    static func minutes(_ amount: Int) -> TimeInterval {
        .seconds(60) * TimeInterval(amount)
    }

    static func hours(_ amount: Int) -> TimeInterval {
        .minutes(60) * TimeInterval(amount)
    }

    static func days(_ amount: Int) -> TimeInterval {
        .hours(24) * TimeInterval(amount)
    }
}
