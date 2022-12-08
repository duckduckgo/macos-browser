//
//  TabExtensions.swift
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

import Combine
import Foundation

@resultBuilder
struct TabExtensionsBuilder {
    static func buildBlock(_ components: any TabExtension...) -> TabExtensions {
        TabExtensions(components: components)
    }
}

protocol TabExtensionInstantiation {
    @TabExtensionsBuilder func make(with dependencies: TabExtensionDependencies) -> TabExtensions
}

struct TabExtensions {
    typealias ExtensionType = TabExtension

    private(set) var extensions: [AnyKeyPath: any TabExtension]

    static func builder() -> TabExtensionInstantiation {
#if DEBUG
        AppDelegate.isRunningTests ? TestTabExtensions() : AppTabExtensions()
#else
        AppTabExtensions()
#endif
    }

    init(components: [any TabExtension]) {
        var extensions = [AnyKeyPath: any TabExtension]()
        func add<T: TabExtension>(_ tabExtension: T) {
            assert(extensions[\T.self] == nil)
            extensions[\T.self] = tabExtension
        }
        components.forEach { add($0) }
        self.extensions = extensions
    }

    func resolve<T: TabExtension>(_: T.Type) -> T.PublicProtocol? {
        (extensions[\T.self] as? T)?.getPublicProtocol()
    }

    func resolve<T: TabExtension>(_: T.Type) -> T.PublicProtocol? where T.PublicProtocol == T {
        fatalError("ok, please don‘t cheat")
    }

}

extension TabExtensions: Sequence {
    typealias Iterator = Dictionary<AnyKeyPath, ExtensionType>.Values.Iterator

    func makeIterator() -> Iterator {
        self.extensions.values.makeIterator()
    }

}
