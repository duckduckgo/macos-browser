//
//  LocaleExtension.swift
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

extension Locale {

    enum DateComponentOrder {
        case dayMonthYear
        case monthDayYear
    }

    var dateComponentOrder: DateComponentOrder {
        guard let format = DateFormatter.dateFormat(fromTemplate: "MMMMd", options: 0, locale: self) else {
            // Default to the North American ordering.
            return .monthDayYear
        }

        if format.hasPrefix("d") {
            return .dayMonthYear
        } else {
            return .monthDayYear
        }
    }

}
