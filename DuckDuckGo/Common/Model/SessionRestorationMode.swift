//
//  SessionRestorationMode.swift
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
import AppKit

enum SessionRestorationMode: RawRepresentable {
    typealias RawValue = Bool?

    case systemDefined
    case always
    case never

    init(rawValue: Bool?) {
        switch rawValue {
        case .none:
            self = .systemDefined
        case .some(true):
            self = .always
        case .some(false):
            self = .never
        }
    }

    var rawValue: Bool? {
        switch self {
        case .systemDefined:
            return nil
        case .always:
            return true
        case .never:
            return false
        }
    }

}

extension SessionRestorationMode {

    var controlStateValue: NSControl.StateValue {
        switch self {
        case .always:
            return NSControl.StateValue.on
        case .never:
            return NSControl.StateValue.off
        case .systemDefined:
            return NSControl.StateValue.mixed
        }
    }

    mutating func toggle() {
        switch self {
        case .systemDefined:
            self = .always
        case .always:
            self = .never
        case .never:
            self = .systemDefined
        }
    }

}
