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

protocol TabExtension {
    init()
    func attach(to tab: Tab)

    func encode(using coder: NSCoder)
    func awakeAfter(using decoder: NSCoder)
}
extension TabExtension {
    func encode(using coder: NSCoder) {}
    func awakeAfter(using coder: NSCoder) {}
}

struct TabExtensions {

    let adClickAttribution: AdClickAttributionTabExtension?
    let contextMenu: ContextMenuManager?
    let hoveredLinks: HoveredLinkTabExtension?
    let printing: TabPrintExtension?
    let findInPage: FindInPageTabExtension?
    let autofill: AutofillTabExtension?

    @Injected(forTests: extensionsForTests)
    static var createExtensions: () -> TabExtensions = {
        TabExtensions(adClickAttribution: AdClickAttributionTabExtension(),
                      contextMenu: ContextMenuManager(),
                      hoveredLinks: HoveredLinkTabExtension(),
                      printing: TabPrintExtension(),
                      findInPage: FindInPageTabExtension(),
                      autofill: AutofillTabExtension())
    }

    private static func extensionsForTests() -> TabExtensions {
        TabExtensions(adClickAttribution: nil,
                      contextMenu: nil,
                      hoveredLinks: nil,
                      printing: nil,
                      findInPage: nil,
                      autofill: nil)
    }

    func attach(to tab: Tab) {
        self.forEach { $0.attach(to: tab) }
    }

}

extension TabExtensions: Sequence {
    typealias Iterator = IndexingIterator<[TabExtension]>

    func makeIterator() -> Iterator {
        Mirror(reflecting: self).children.compactMap { child -> TabExtension? in
            guard let tabExtension = child.value as? TabExtension else {
                assertionFailure("\(child.label!) should conform to TabExtension")
                return nil
            }
            return tabExtension
        }.makeIterator()
    }

}
