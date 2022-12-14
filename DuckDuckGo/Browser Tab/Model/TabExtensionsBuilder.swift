//
//  TabExtensionsBuilder.swift
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
import os.log

protocol TabExtensionsBuilderProtocol {
    func build(with args: TabExtensionsBuilderArguments, dependencies: TabExtensionDependencies) -> TabExtensions
}

// !! Register Tab Extensions in TabExtensions.swift

/// Tab Extensions registration component
/// defines intialization order and provides dependencies to the Tab Extensions initalizers
struct TabExtensionsBuilder: TabExtensionsBuilderProtocol {

    static var `default`: TabExtensionsBuilderProtocol {
#if DEBUG
        return AppDelegate.isRunningTests ? TestTabExtensionsBuilder.default : TabExtensionsBuilder()
#else
        return TabExtensions()
#endif
    }

    var components = [(type: any TabExtension.Type, buildingBlock: AnyTabExtensionBuildingBlock)]()

    /// collect Tab Extensions instantiation blocks (`add { }` method calls)
    /// lazy for Unit Tests builds and non-lazy in Production
    @discardableResult
    mutating func add<Extension: TabExtension>(_ makeTabExtension: @escaping () -> Extension) -> TabExtensionBuildingBlock<Extension> {
        let buildingBlock = TabExtensionBuildingBlock(makeTabExtension)
        components.append( (type: Extension.self, buildingBlock: buildingBlock) )
        return buildingBlock
    }

    /// build TabExtensions struct from blocks collected above
    func build(with args: TabExtensionsBuilderArguments, dependencies: TabExtensionDependencies) -> TabExtensions {
        var builder = self
        builder.registerExtensions(with: args, dependencies: dependencies)
        return TabExtensions(components: builder.components.map { $0.buildingBlock.make() })
    }

}

#if DEBUG
/// TabExtensionsBuilder loaded by default when running Tests
/// by default loads only extensions passed in `load` argument,
/// set default extensions to load in TestTabExtensionsBuilder.default
/// provide overriding extensions initializers in `overrideExtensions` method using `override { .. }` calls
final class TestTabExtensionsBuilder: TabExtensionsBuilderProtocol {
    private var components = [(type: any TabExtension.Type, buildingBlock: AnyTabExtensionBuildingBlock)]()

    var extensionsToLoad = [any TabExtension.Type]()
    private let overrideExtensionsFunc: (TestTabExtensionsBuilder) -> (TabExtensionsBuilderArguments, TabExtensionDependencies) -> Void

    init(load extensionsToLoad: [any TabExtension.Type],
         overrideExtensions: @escaping (TestTabExtensionsBuilder) -> (TabExtensionsBuilderArguments, TabExtensionDependencies) -> Void = TestTabExtensionsBuilder.overrideExtensions) {
        self.extensionsToLoad = extensionsToLoad
        self.overrideExtensionsFunc = overrideExtensions
    }

    convenience init(overrideExtensions: @escaping (TestTabExtensionsBuilder) -> (TabExtensionsBuilderArguments, TabExtensionDependencies) -> Void,
                     _ extensionsToLoad: [any TabExtension.Type]) {
        self.init(load: extensionsToLoad, overrideExtensions: overrideExtensions)
    }

    convenience init(load extensionToLoad: any TabExtension.Type,
                     overrideExtensions: @escaping (TestTabExtensionsBuilder) -> (TabExtensionsBuilderArguments, TabExtensionDependencies) -> Void = TestTabExtensionsBuilder.overrideExtensions) {
        self.init(load: [extensionToLoad], overrideExtensions: overrideExtensions)
    }

    func build(with args: TabExtensionsBuilderArguments, dependencies: TabExtensionDependencies) -> TabExtensions {
        var builder = TabExtensionsBuilder()
        builder.registerExtensions(with: args, dependencies: dependencies)

        self.components = builder.components.filter { component in extensionsToLoad.contains(where: { component.type == $0 }) }
        self.overrideExtensionsFunc(self)(args, dependencies)

        return TabExtensions(components: components.map { $0.buildingBlock.make() })
    }

    /// collect Tab Extensions instantiation blocks (`add { }` method calls)
    /// lazy for Unit Tests builds and non-lazy in Production
    @discardableResult
    func override<Extension: TabExtension>(_ makeTabExtension: @escaping () -> Extension) -> TabExtensionBuildingBlock<Extension> {
        let builderBlock = TabExtensionBuildingBlock(makeTabExtension)
        guard let idx = components.firstIndex(where: { $0.type == Extension.self }) else {
            return TabExtensionBuildingBlock {
                fatalError("Trying to initialize an extension not specified in TestTabExtensionsBuilder.extensionsToLoad: \(Extension.self)")
            }
        }
        guard case .lazy(let loader) = (components[idx].buildingBlock as? TabExtensionBuildingBlock<Extension>)?.state,
              case .none = loader.state
        else {
            fatalError("\(Extension.self) has been already initialized at the moment of the `override` call")
        }
        loader.state = .none(makeTabExtension)

        return builderBlock
    }

    /// use to retreive Extension Building Blocks registered during TabExtensionsBuilder.registerExtensions
    func get<Extension: TabExtension>(_: Extension.Type) -> TabExtensionBuildingBlock<Extension> {
        guard let buildingBlock = components.first(where: { $0.type == Extension.self })?.buildingBlock else {
            fatalError("\(Extension.self) not registered in TabExtensionsBuilder.registerExtensions")
        }
        return (buildingBlock as? TabExtensionBuildingBlock<Extension>)!
    }

}
#endif

@dynamicMemberLookup
struct TabExtensionBuildingBlock<Extension: TabExtension> {
#if DEBUG

    fileprivate enum State {
        case loaded(Extension)
        case lazy(TabExtensionLazyLoader<Extension>)
    }
    fileprivate let state: State
    var value: Extension {
        switch state {
        case .loaded(let value): return value
        case .lazy(let loader): return loader.value
        }
    }

    init(_ makeTabExtension: @escaping () -> Extension) {
        if AppDelegate.isRunningTests {
            state = .lazy(.init(makeTabExtension))
        } else {
            state = .loaded(makeTabExtension())
        }
    }

#else

    let value: Extension

    init(_ makeTabExtension: @escaping () -> Extension) {
        self.value = makeTabExtension()
    }

#endif

    subscript<T>(dynamicMember keyPath: KeyPath<Extension, T>) -> T {
        self.value[keyPath: keyPath]
    }
}
protocol AnyTabExtensionBuildingBlock {
    func make() -> any TabExtension
}
extension TabExtensionBuildingBlock: AnyTabExtensionBuildingBlock {
    func make() -> any TabExtension {
        self.value
    }
}

#if DEBUG
private final class TabExtensionLazyLoader<Extension: TabExtension> {
    fileprivate enum State {
        case none(() -> Extension)
        case some(Extension)
    }
    fileprivate var state: State

    var value: Extension {
        if case .none(let makeTabExtension) = state {
            state = .some(makeTabExtension())
        }
        guard case .some(let value) = state else { fatalError() }
        return value
    }

    init(_ makeTabExtension: @escaping () -> Extension) {
        self.state = .none(makeTabExtension)
    }
}
#endif

struct TabExtensions {
    typealias ExtensionType = TabExtension

    private(set) var extensions: [AnyKeyPath: any TabExtension]

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
        let tabExtension = (extensions[\T.self] as? T)?.getPublicProtocol()
#if DEBUG
        assert(AppDelegate.isRunningTests || tabExtension != nil)
#else
        os_log("%s Tab Extension not initialised for Unit Tests, activate it in TabExtensions.swift", log: .autoconsent, type: .debug, "\(T.self)")
#endif
        return tabExtension
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
