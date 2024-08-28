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
import AppKit
import Common
import os.log

protocol TabExtensionsBuilderProtocol {
    @MainActor
    func build(with args: TabExtensionsBuilderArguments, dependencies: TabExtensionDependencies) -> TabExtensions
}

// !! Register Tab Extensions in TabExtensions.swift

/// Tab Extensions registration component
/// defines intialization order and provides dependencies to the Tab Extensions initalizers
struct TabExtensionsBuilder: TabExtensionsBuilderProtocol {

    static var `default`: TabExtensionsBuilderProtocol {
#if DEBUG
        return NSApp.runType.requiresEnvironment ? TabExtensionsBuilder() : TestTabExtensionsBuilder.shared
#else
        return TabExtensionsBuilder()
#endif
    }

    var components = [(protocolType: Any.Type, buildingBlock: any TabExtensionBuildingBlockProtocol)]()

    /// collect Tab Extensions instantiation blocks (`add { }` method calls)
    /// lazy for Unit Tests builds and non-lazy in Production
    @discardableResult
    mutating func add<Extension: TabExtension>(_ makeTabExtension: @escaping () -> Extension) -> TabExtensionBuildingBlock<Extension.PublicProtocol> {
        let buildingBlock = TabExtensionBuildingBlock(makeTabExtension)
        components.append( (protocolType: Extension.PublicProtocol.self, buildingBlock: buildingBlock) )
        return buildingBlock
    }

    /// build TabExtensions struct from blocks collected above
    @MainActor
    func build(with args: TabExtensionsBuilderArguments, dependencies: TabExtensionDependencies) -> TabExtensions {
        var builder = self
        builder.registerExtensions(with: args, dependencies: dependencies)
        return TabExtensions(components: builder.components.map { $0.buildingBlock.make() })
    }

}

#if DEBUG
/// TabExtensionsBuilder loaded by default when running Tests
/// by default loads only extensions passed in `load` argument,
/// set default extensions to load in TestTabExtensionsBuilder.shared
/// provide overriding extensions initializers in `overrideExtensions` method using `override { .. }` calls
final class TestTabExtensionsBuilder: TabExtensionsBuilderProtocol {

    private var components = [(protocolType: Any.Type, buildingBlock: (any TabExtensionBuildingBlockProtocol))]()

    var extensionsToLoad: [any TabExtension.Type]?
    private let overrideExtensionsFunc: (TestTabExtensionsBuilder) -> (TabExtensionsBuilderArguments, TabExtensionDependencies) -> Void

    init(load extensionsToLoad: [any TabExtension.Type]? = nil,
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

        self.components = builder.components.filter { component in
            extensionsToLoad?.contains(where: {
                $0.publicProtocolType == component.protocolType
            }) ?? true
        }
        self.overrideExtensionsFunc(self)(args, dependencies)

        return TabExtensions(components: components.map { $0.buildingBlock.make() })
    }

    /// override Tab Extensions instantiation blocks provided in TabExtensionsBuilder  (`override { }` method calls)
    @discardableResult
    func override<Extension: TabExtension>(_ makeTabExtension: @escaping () -> Extension) -> TabExtensionBuildingBlock<Extension.PublicProtocol> {
        let builderBlock = TabExtensionBuildingBlock(makeTabExtension)
        guard let idx = components.firstIndex(where: { $0.protocolType == Extension.PublicProtocol.self }) else {
            return TabExtensionBuildingBlock { () -> Extension in
                fatalError("Trying to initialize an extension not specified in TestTabExtensionsBuilder.extensionsToLoad: \(Extension.self)")
            }
        }
        guard case .lazy(let loader) = (components[idx].buildingBlock as? TabExtensionBuildingBlock<Extension.PublicProtocol>)?.state,
              case .none = loader.state
        else {
            fatalError("\(type(of: components[idx].buildingBlock)) has been already initialized at the moment of the `override` call")
        }
        loader.state = TabExtensionLazyLoader<Extension.PublicProtocol>.State.none { makeTabExtension().getPublicProtocol() }

        return builderBlock
    }

    /// collect Tab Extensions instantiation blocks (`add { }` method calls)
    /// lazy for Unit Tests builds and non-lazy in Production
    @discardableResult
    func add<Extension: TabExtension>(_ makeTabExtension: @escaping () -> Extension) -> TabExtensionBuildingBlock<Extension.PublicProtocol> {
        let buildingBlock = TabExtensionBuildingBlock(makeTabExtension)
        components.append( (protocolType: Extension.PublicProtocol.self, buildingBlock: buildingBlock) )
        return buildingBlock
    }

    /// use to retreive Extension Building Blocks registered during TabExtensionsBuilder.registerExtensions
    func get<Extension: TabExtension>(_: Extension.Type) -> TabExtensionBuildingBlock<Extension> {
        guard let buildingBlock = components.first(where: { $0.protocolType == Extension.PublicProtocol.self })?.buildingBlock else {
            fatalError("\(Extension.self) not registered in TabExtensionsBuilder.registerExtensions")
        }
        return (buildingBlock as? TabExtensionBuildingBlock<Extension>)!
    }

}
#endif

@dynamicMemberLookup
struct TabExtensionBuildingBlock<T> {
#if DEBUG

    fileprivate enum State {
        case loaded(T)
        case lazy(TabExtensionLazyLoader<T>)
    }
    fileprivate let state: State
    var value: T {
        switch state {
        case .loaded(let value): return value
        case .lazy(let loader): return loader.value
        }
    }

    init<Extension: TabExtension>(_ makeTabExtension: @escaping () -> Extension) where Extension.PublicProtocol == T {
        if NSApp.runType.requiresEnvironment {
            state = .loaded(makeTabExtension().getPublicProtocol())
        } else {
            state = .lazy(.init(makeTabExtension))
        }
    }

#else

    let value: T

    init<Extension: TabExtension>(_ makeTabExtension: @escaping () -> Extension) where Extension.PublicProtocol == T {
        self.value = makeTabExtension().getPublicProtocol()
    }

#endif

    subscript<P>(dynamicMember keyPath: KeyPath<T, P>) -> P {
        self.value[keyPath: keyPath]
    }

    func make() -> any TabExtension {
        return (value as? any TabExtension)!
    }
}

protocol TabExtensionBuildingBlockProtocol {
    func make() -> any TabExtension
}
extension TabExtensionBuildingBlock: TabExtensionBuildingBlockProtocol {}

#if DEBUG
private final class TabExtensionLazyLoader<T> {
    fileprivate enum State {
        case none(() -> T)
        case some(T)
    }
    fileprivate var state: State

    var value: T {
        if case .none(let makeTabExtension) = state {
            state = .some(makeTabExtension())
        }
        guard case .some(let value) = state else { fatalError() }
        return value
    }

    init<Extension: TabExtension>(_ makeTabExtension: @escaping () -> Extension) where Extension.PublicProtocol == T {
        self.state = .none { makeTabExtension().getPublicProtocol() }
    }
}
#endif

struct TabExtensions {
    typealias ExtensionType = TabExtension

    private(set) var extensions: [ObjectIdentifier: any TabExtension]

    init(components: [any TabExtension]) {
        var extensions = [ObjectIdentifier: any TabExtension]()
        func add<T: TabExtension>(_ tabExtension: T) {
            let key = ObjectIdentifier(T.PublicProtocol.self)
            assert(extensions[key] == nil)
            extensions[key] = tabExtension
        }
        components.forEach { add($0) }
        self.extensions = extensions
    }

    enum NullableExtension {
        case nullable
    }
    func resolve<T: TabExtension>(_: T.Type, _ isNullable: NullableExtension? = nil) -> T.PublicProtocol? {
        let tabExtension = extensions[ObjectIdentifier(T.PublicProtocol.self)]?.getPublicProtocol() as? T.PublicProtocol
        guard isNullable != .nullable else { return tabExtension}
#if DEBUG
        assert(!NSApp.runType.requiresEnvironment || tabExtension != nil)
#else
        Logger.autoconsent.debug("Tab Extension not initialised for Unit Tests, activate it in TabExtensions.swift")
#endif
        return tabExtension
    }

    func resolve<T: TabExtension>(_: T.Type, _ isNullable: NullableExtension? = nil) -> T.PublicProtocol? where T.PublicProtocol == T {
        fatalError("ok, please don‘t cheat")
    }

}

extension TabExtensions: Sequence {
    typealias Iterator = Dictionary<ObjectIdentifier, any ExtensionType>.Values.Iterator

    func makeIterator() -> Iterator {
        self.extensions.values.makeIterator()
    }

}
