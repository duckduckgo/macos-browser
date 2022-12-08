//
//  Extensions.swift
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

protocol Extension {}

// Implement these methods for Extension State Restoration
protocol NSCodingExtension: Extension {
    func encode(using coder: NSCoder)
    func awakeAfter(using decoder: NSCoder)
}

protocol Extensions: Sequence where Iterator == Dictionary<AnyKeyPath, ExtensionType>.Values.Iterator {

    associatedtype ExtensionType

    var extensions: [AnyKeyPath: ExtensionType] { get }
}

extension Extensions {

    func makeIterator() -> Iterator {
        self.extensions.values.makeIterator()
    }

}
