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

@objc protocol ObjcExtensionResolvingHelper: AnyObject {
}
protocol ExtensionResolvingHelper: ObjcExtensionResolvingHelper {
    associatedtype OwnerType: Extendable
    associatedtype ExtensionType: Extension

    static func make(owner: OwnerType) -> ExtensionType
}

protocol Extension {
}

protocol TabExtension: Extension { associatedtype ResolvingHelper: TabExtensionResolvingHelper }
protocol TabExtensionResolvingHelper: ExtensionResolvingHelper where OwnerType == Tab, ExtensionType: TabExtension {}

extension ExtensionResolvingHelper {
    static var ownerType: OwnerType.Type { OwnerType.self }
}

protocol Extendable {}
extension Tab: Extendable {}

protocol NSCodingExtension: Extension {
    func encode(using coder: NSCoder)
    func awakeAfter(using decoder: NSCoder)
}
extension Extension {
    func encode(using coder: NSCoder) {}
    func awakeAfter(using coder: NSCoder) {}
}

struct TabExtensions {
    typealias Dependencies = AdClickAttributionTabExtension.Dependencies

    // TODO: Finish converting these and Autofill to TabExtension
    var hoveredLinks: HoveredLinkTabExtension?
    var findInPage: FindInPageTabExtension?

    private static var initExtensionsOnce: [AnyKeyPath: [any ExtensionResolvingHelper.Type]] = {
        let resolvingHelpers = getClasses(conformingTo: ObjcExtensionResolvingHelper.self)
        print(resolvingHelpers)
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
        let extTypes = Self.initExtensionsOnce[\Tab.self]!.map { ($0 as? any TabExtensionResolvingHelper.Type)! }
        var extensions = [AnyKeyPath: any TabExtension]()
        func add<T: TabExtensionResolvingHelper>(_ type: T.Type) {
            assert(extensions[\T.ExtensionType.self] == nil)
            extensions[\T.ExtensionType.self] = type.make(owner: tab)
        }
        extTypes.forEach { add($0) }
        self.extensions = extensions
    }

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
