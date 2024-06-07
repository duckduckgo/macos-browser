//
//  PDFSearchTextMenuItemHandler.swift
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

import Foundation

@MainActor
final class PDFSearchTextMenuItemHandler: NSObject {

    private static let _NSServiceEntry: AnyClass? = NSClassFromString("_NSServiceEntry")
    private static let originalInvokeWithPasteboard = {
        class_getInstanceMethod(_NSServiceEntry, NSSelectorFromString("invokeWithPasteboard:"))
    }()
    private static func swizzledInvokeWithPasteboard() -> Method? {
        class_getInstanceMethod(_NSServiceEntry, #selector(swizzled_invokeWithPasteboard(_:)))
    }

    static func swizzleInvokeWithPasteboardOnce() {
        guard let NSServiceEntry = self._NSServiceEntry,
              swizzledInvokeWithPasteboard() == nil,
              let originalInvokeWithPasteboard = originalInvokeWithPasteboard,
              let imp = class_getMethodImplementation(PDFSearchTextMenuItemHandler.self, #selector(swizzled_invokeWithPasteboard(_:)))
        else { return }

        class_addMethod(NSServiceEntry,
                        #selector(swizzled_invokeWithPasteboard(_:)),
                        imp,
                        method_getTypeEncoding(originalInvokeWithPasteboard))

        guard let addedInvokeWithPasteboard = swizzledInvokeWithPasteboard() else { return }
        method_exchangeImplementations(originalInvokeWithPasteboard, addedInvokeWithPasteboard)
    }

    @objc
    func swizzled_invokeWithPasteboard(_ pasteboard: NSPasteboard) {
        guard let declaredType = pasteboard.types?.first,
              let selectedText = pasteboard.string(forType: declaredType),
              let url = URL.makeURL(from: selectedText)
        else { return }

        WindowControllersManager.shared.show(url: url, source: .link, newTab: true)
    }

}
