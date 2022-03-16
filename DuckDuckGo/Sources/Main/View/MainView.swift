//
//  MainView.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Cocoa

final class MainView: NSView {
    private typealias CFWebServicesCopyProviderInfoType = @convention(c) (CFString, UnsafeRawPointer?) -> NSDictionary?

    // PDF Plugin context menu
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        setupSearchContextMenuItem(menu: menu)
    }

    private func setupSearchContextMenuItem(menu: NSMenu) {
        // Intercept [_NSServiceEntry invokeWithPasteboard:] to catch selected PDF text "Search with %@" menu item
        PDFSearchTextMenuItemHandler.swizzleInvokeWithPasteboardOnce()

        // Get system default Search Engine name
        guard let CFWebServicesCopyProviderInfo: CFWebServicesCopyProviderInfoType? = dynamicSymbol(named: "_CFWebServicesCopyProviderInfo"),
              let info = CFWebServicesCopyProviderInfo?("NSWebServicesProviderWebSearch" as CFString, nil),
              let providerDisplayName = info["NSDefaultDisplayName"] as? String,
              providerDisplayName != "DuckDuckGo"
        else { return }

        // Find the "Search with %@" item and replace %@ with DuckDuckGo
        for item in menu.items {
            guard !item.isSeparatorItem else { break }
            if item.title.contains(providerDisplayName) {
                item.title = item.title.replacingOccurrences(of: providerDisplayName, with: "DuckDuckGo")
                break
            }
        }
    }

}
