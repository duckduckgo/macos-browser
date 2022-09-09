//
//  Date+Import.swift
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

extension Date {

    private enum Const {
        static let macEpochOffset: TimeInterval = 978307199
        static let chromiumEpochOffset: TimeInterval = 11644473600
    }

    init(macTimestamp: TimeInterval) {
        let timeIntervalSince1970 = macTimestamp + Const.macEpochOffset
        self.init(timeIntervalSince1970: timeIntervalSince1970)
    }

    var macTimestamp: TimeInterval {
        timeIntervalSince1970 - Const.macEpochOffset
    }

    init(chromiumTimestamp: Int64) {
        let seconds = Int(chromiumTimestamp / 1000000)
        self.init(timeIntervalSince1970: TimeInterval(seconds) - Const.chromiumEpochOffset)
    }

    var chromiumTimestamp: Int64 {
        Int64((timeIntervalSince1970 + Const.chromiumEpochOffset) * 1000000)
    }
}
