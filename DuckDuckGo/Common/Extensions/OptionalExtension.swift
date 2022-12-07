//
//  OptionalExtension.swift
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

protocol OptionalProtocol {
    associatedtype Wrapped

    var isNil: Bool { get }

    /// instantiate a Concrete-Typed `Optional<Wrapped>.none as T` from an `AnyOptionalType`
    /// can be used to return nil value for a maybe-optional Generic Type
    /// usage: `(T.self as? AnyOptionalType)?.none as? T`
    static var none: Self { get }
}
typealias AnyOptional = any OptionalProtocol
typealias AnyOptionalType = any OptionalProtocol.Type

extension Optional: OptionalProtocol {

    var isNil: Bool {
        if case .none = self {
            return true
        }
        return false
    }

}
