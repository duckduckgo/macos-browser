//
//  Tab+Extensions.swift
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

protocol TabExtension {
    init(tab: Tab)
}

@dynamicMemberLookup
struct DynamicTabExtensions {
    private var storage = [AnyKeyPath: TabExtension]()

    subscript<T: TabExtension>(dynamicMember keyPath: KeyPath<TabExtensions, T.Type>) -> T {
        (storage[\T.self] as? T)!
    }

    mutating func register<T: TabExtension>(_ tabExtension: T) {
        assert(storage[\T.self] == nil, "Trying to register \(T.self) twice!")
        storage[\T.self] = tabExtension
    }

}

protocol ExtensionsBuilder {
    func buildExtensions(for tab: Tab) -> DynamicTabExtensions
}

struct TabExtensionsBuilder: ExtensionsBuilder {

    func buildExtensions(for tab: Tab) -> DynamicTabExtensions {
        var result = DynamicTabExtensions()
        for child in Mirror(reflecting: TabExtensions()).children {
            guard let extensionType = child.value as? TabExtension.Type else {
                assertionFailure("\(child.label!) should be TabExtension.Type")
                continue
            }
            result.register(extensionType.init(tab: tab))
        }
        return result
    }

}
