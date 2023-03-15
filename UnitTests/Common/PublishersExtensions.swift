//
//  PublishersExtensions.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Combine
import Foundation

struct TimeoutError: Error, LocalizedError {

    let interval: TimeInterval?
    let file: StaticString
    let line: UInt

    init(interval: TimeInterval? = nil, file: StaticString = #file, line: UInt = #line) {
        self.interval = interval
        self.file = file
        self.line = line
    }

    var errorDescription: String? {
        "TimeoutError: exceeded timeout\(interval != nil ? " of \(interval!)s" : "") at \(file):\(line)"
    }

}

extension Publisher where Failure == Never {

    func timeout(_ interval: TimeInterval, file: StaticString = #file, line: UInt = #line) -> Publishers.Timeout<Publishers.MapError<Self, TimeoutError>, DispatchQueue> {
        return self.mapError { _ -> TimeoutError in }
            .timeout(.seconds(interval), scheduler: DispatchQueue.main, customError: { TimeoutError(interval: interval, file: file, line: line) })
    }

}
