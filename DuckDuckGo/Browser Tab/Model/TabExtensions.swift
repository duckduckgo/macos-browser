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

// swiftlint:disable trailing_comma
extension TabExtensions {

    /// !!!!!
    /// Add `TabExtension`-s for App builds here
    /// Note: Extensions with state restoration support should conform to `NSCodingExtension`
    /// !!!!!
    static var tabExtensions: [(Tab) -> TabExtension] { [
        AdClickAttributionTabExtension.make,
        ContextMenuManager.make,
        FindInPageTabExtension.make,
        HoveredLinkTabExtension.make,
        AutofillTabExtension.make,
    ] } 

    /// Add `TabExtension`-s that should be loaded when running Unit Tests here
    /// By default the Extensions won‘t be loaded
    static var tabExtensionsInstantiatedForTests: [(Tab) -> TabExtension] { [
        // SomeTabExtension.make, ...
    ] }

}

/**
 `TabExtension` should implement the `make` factory method for instantiation with a `Tab` owner
 Avoid making strong dependencies on the `Tab` class for Tab Extensions to keep them testable

 e.g.:
 class MyExtension {
   typealias Dependencies = DependencyProtocol1 & DependencyProtocol2...
   // Do not provide the Tab directly to init method for testability purposes
   init(dependencies: some Dependencies) {..}
   func someFeature() {}
 }

 extension MyExtension: TabExtension {
   static func make(owner tab: Tab) -> MyExtension {
     MyExtension(dependencies: tab.dependencies)
   }
 }
**/

protocol TabExtension {
    static func make(owner tab: Tab) -> Self
}

/// `TabExtension`-s are resoved dynamically in runtime
/// using `TabExtensions.tabExtensions` or `TabExtensions.tabExtensionsInstantiatedForTests` lists
/// An extension should conform to TabExtension protocol
struct TabExtensions: Extensions, Sequence {
    typealias ExtensionType = TabExtension
    typealias Iterator = Dictionary<AnyKeyPath, ExtensionType>.Values.Iterator

    private(set) var extensions: [AnyKeyPath: TabExtension]

    init(_ tab: Tab) {
        var extensions = [AnyKeyPath: TabExtension]()
        func add<T: TabExtension>(_ tabExtension: T) {
            assert(extensions[\T.self] == nil)
            extensions[\T.self] = tabExtension
        }

#if DEBUG
        if AppDelegate.isRunningTests {
            for constructor in Self.tabExtensionsInstantiatedForTests {
                add(constructor(tab))
            }
        } else {
            for constructor in Self.tabExtensions {
                add(constructor(tab))
            }
        }
#else
        for constructor in Self.tabExtensions {
            add(constructor(tab))
        }
#endif
        self.extensions = extensions
    }

    /** Used for resolving a TabExtension object in the TabExtensions struct extension,
     e.g. for `tab.extensions.someTabExtension` add:

     extension TabExtensions {
       var someTabExtension: MyTabExtension? {
         resolve()
       }
     }
     **/
    func resolve<T: TabExtension>() -> T? {
        extensions[\T.self] as? T
    }

    func resolve<T: TabExtension>() -> T {
        resolve()!
    }

}
