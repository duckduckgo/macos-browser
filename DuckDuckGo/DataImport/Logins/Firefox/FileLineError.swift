//
//  FileLineError.swift
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

import Foundation

/// Error pointing to the failing line
struct FileLineError<Owner>: Error, CustomNSError {

    var line: UInt

    var errorCode: Int {
        Int(line)
    }

    static var errorDomain: String {
        "\(Owner.self).FileLineError"
    }

    init(line: UInt = #line) {
        self.line = line
    }

    static func nextLine(line: UInt = #line) -> Self {
        self.init(line: line + 1)
    }

    /// Use in guard statements to move the line error pointer to the next line
    mutating func next(line: UInt = #line) -> Bool {
        self.line = line + 1
        return true
    }

}
