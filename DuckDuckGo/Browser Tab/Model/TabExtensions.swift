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

import Foundation

// base protocol for Dynamic ObjC Extensions discovery
@objc protocol ObjcExtensionResolvingHelper: AnyObject {
}
protocol ExtensionResolvingHelper: ObjcExtensionResolvingHelper {
    associatedtype OwnerType: Extendable
    associatedtype ExtensionType: Extension

    /// Create an instance of the Extension for App Build or for Standalone Testing
    static func make(owner: OwnerType) -> ExtensionType
    /// Create a default instance of the Extension for a regular Owner or for Integrated Testing - will return nil by default
    static func makeForTesting(owner: OwnerType) -> ExtensionType?
}

extension ExtensionResolvingHelper {
    // No extensions are created by default for Tests
    // Override this method in an extension ResolvingHelper if you need to instantiate an extension during Tests
    static func makeForTesting(owner: OwnerType) -> ExtensionType? {
        nil
    }
}

protocol Extension {}

// Each TabExtension should contain an inner ResolvingHelper objc class instantiating the Extension with a Tab
/* e.g.
 class MyExtension {
     typealias Dependencies = DependencyProtocol1 & DependencyProtocol2...
     // Do not provide the Tab directly to init method for testability purposes
     init(dependencies: some Dependencies) {..}
     func someFeature() {}
 }

 extension MyExtension: TabExtension {
     final class ResolvingHelper: TabExtensionResolvingHelper {
         static func make(owner tab: Tab) -> MyExtension {
             MyExtension(dependencies: tab.dependencies)
         }
     }
 }

 */
protocol TabExtension: Extension { associatedtype ResolvingHelper: TabExtensionResolvingHelper }
protocol TabExtensionResolvingHelper: ExtensionResolvingHelper where OwnerType == Tab, ExtensionType: TabExtension {}

extension ExtensionResolvingHelper {
    static var ownerType: OwnerType.Type { OwnerType.self }
}

protocol Extendable {}
extension Tab: Extendable {}

// Implement these methods for Extension State Restoration
protocol NSCodingExtension: Extension {
    func encode(using coder: NSCoder)
    func awakeAfter(using decoder: NSCoder)
}

// TabExtensions are resoved dynamically in runtime
// An extension should conform the TabExtension protocol
struct TabExtensions {

    private static var initExtensionsOnce: [AnyKeyPath: [any ExtensionResolvingHelper.Type]] = {
        // get all classes conforming to ObjcExtensionResolvingHelper protocol
        let resolvingHelpers = getClasses(conformingTo: ObjcExtensionResolvingHelper.self)
        // Store the Resolver Class Type in [\OwnerType.self : Array<Resolver.Type>] dict e.g. [\Tab.self: [Resolver.Type]]
        var result = [AnyKeyPath: [any ExtensionResolvingHelper.Type]]()
        for helperType in resolvingHelpers {
            let resolverType = (helperType as? any ExtensionResolvingHelper.Type)!
            func add<T: ExtensionResolvingHelper>(_: T.Type) {
                result[\(T.OwnerType).self, default: []].append(resolverType)
            }
            add(resolverType)
        }
        return result
    }()

    fileprivate var extensions: [AnyKeyPath: any TabExtension]

    init(_ tab: Tab) {
        // get all the TabExtension types
        let extTypes = Self.initExtensionsOnce[\Tab.self]!.map { ($0 as? any TabExtensionResolvingHelper.Type)! }
        var extensions = [AnyKeyPath: any TabExtension]()
        // instantiate each of the Tab Extensions with +make(owner: tab) or +makeForTests(owner: tab)
        func add<T: TabExtensionResolvingHelper>(_ type: T.Type) {
            assert(extensions[\T.ExtensionType.self] == nil)
#if DEBUG
            if AppDelegate.isRunningTests {
                extensions[\T.ExtensionType.self] = type.makeForTesting(owner: tab)
            } else {
                extensions[\T.ExtensionType.self] = type.make(owner: tab)
            }
#else
            extensions[\T.ExtensionType.self] = type.make(owner: tab)
#endif
        }
        extTypes.forEach { add($0) }
        self.extensions = extensions
    }

    // Used for dynamic resolving the TabExtension value in TabExtensions extension
    /* e.g.
        extension TabExtensions {
            var someTabExtension: MyTabExtension? { resolve() }
        }
     */
    func resolve<T: TabExtension>() -> T {
        resolve()!
    }

    func resolve<T: TabExtension>() -> T? {
        extensions[\T.self] as? T
    }

}

extension TabExtensions: Sequence {
    typealias Iterator = Dictionary<AnyKeyPath, any TabExtension>.Values.Iterator

    func makeIterator() -> Iterator {
        self.extensions.values.makeIterator()
    }

}
