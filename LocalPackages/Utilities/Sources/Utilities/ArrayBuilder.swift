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
public struct ArrayBuilder<Element> {

    @inlinable
    public static func buildBlock() -> [Element] {
        return []
    }

    @inlinable
    public static func buildBlock(_ element: Element) -> [Element] {
        return [element]
    }

    @inlinable
    public static func buildBlock(_ elements: Element...) -> [Element] {
        return elements
    }

    @inlinable
    public static func buildBlock(_ components: [Element]...) -> [Element] {
        return components.flatMap { $0 }
    }

    @inlinable
    public static func buildOptional(_ components: [Element]?) -> [Element] {
        return components ?? []
    }

    @inlinable
    public static func buildEither(first component: Element) -> [Element] {
        return [component]
    }

    @inlinable
    public static func buildEither(first component: [Element]) -> [Element] {
        component
    }

    @inlinable
    public static func buildEither(second component: [Element]) -> [Element] {
        component
    }

    public static func buildLimitedAvailability(_ component: [Element]) -> [Element] {
        component
    }

    @inlinable
    public static func buildArray(_ components: [[Element]]) -> [Element] {
        components.flatMap { $0 }
    }

    @inlinable
    public static func buildExpression(_ expression: [Element]) -> [Element] {
        return expression
    }

    @inlinable
    public static func buildExpression(_ expression: Element) -> [Element] {
        return [expression]
    }

    @inlinable
    public static func buildExpression(_ expression: Element?) -> [Element] {
        return expression.map { [$0] } ?? []
    }

    public static func buildExpression(_ expression: Void) -> [Element] {
        return []
    }

}
