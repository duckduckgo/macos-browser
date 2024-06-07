//
//  ArrayBuilder.swift
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

import AppKit

@resultBuilder
struct ArrayBuilder<Element> {

    @inlinable
    static func buildBlock() -> [Element] {
        return []
    }

    @inlinable
    static func buildBlock(_ element: Element) -> [Element] {
        return [element]
    }

    @inlinable
    static func buildBlock(_ elements: Element...) -> [Element] {
        return elements
    }

    @inlinable
    static func buildBlock(_ components: [Element]...) -> [Element] {
        return components.flatMap { $0 }
    }

    @inlinable
    static func buildOptional(_ components: [Element]?) -> [Element] {
        return components ?? []
    }

    @inlinable
    static func buildEither(first component: Element) -> [Element] {
        return [component]
    }

    @inlinable
    static func buildEither(first component: [Element]) -> [Element] {
        component
    }

    @inlinable
    static func buildEither(second component: [Element]) -> [Element] {
        component
    }

    static func buildLimitedAvailability(_ component: [Element]) -> [Element] {
        component
    }

    @inlinable
    static func buildArray(_ components: [[Element]]) -> [Element] {
        components.flatMap { $0 }
    }

    @inlinable
    static func buildExpression(_ expression: [Element]) -> [Element] {
        return expression
    }

    @inlinable
    static func buildExpression(_ expression: Element) -> [Element] {
        return [expression]
    }

    @inlinable
    static func buildExpression(_ expression: Element?) -> [Element] {
        return expression.map { [$0] } ?? []
    }

    static func buildExpression(_ expression: Void) -> [Element] {
        return []
    }

}
