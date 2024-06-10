//
//  NSPrintInfoExtension.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

extension NSPrintInfo {

//    convenience init(printInfo: NSPrintInfo?) {
//        let originalPrintInfo = printInfo ?? .shared
//        var dict = originalPrintInfo.storage
//
//        let paperSize = originalPrintInfo.paperSize
//        let printableRect = originalPrintInfo.imageablePageBounds
//
//        let leftMargin = printableRect.origin.x
//        let rightMargin = paperSize.width - (printableRect.origin.x + printableRect.size.width)
//        let topMargin = paperSize.height - (printableRect.origin.y + printableRect.size.height)
//        let bottomMargin = printableRect.origin.y
//
//        dict[.leftMargin] = max(0, leftMargin)
//        dict[.rightMargin] = max(0, rightMargin)
//        dict[.topMargin] = max(0, topMargin)
//        dict[.bottomMargin] = max(0, bottomMargin)
//
//        dict[.horizontalPagination] = NSPrintInfo.PaginationMode.fit
//        dict[.verticalPagination] = NSPrintInfo.PaginationMode.fit
//        dict[.verticallyCentered] = false
//        dict[.scalingFactor] = 1.0
//
//        self.init(dictionary: dict)
//    }

    static let minimumPrintSize = NSSize(width: 72, height: 72)

    var validLeftMarginRange: Range<CGFloat> {
        return 0..<max(0, paperSize.width - rightMargin - Self.minimumPrintSize.width)
    }

    var validRightMarginRange: Range<CGFloat> {
        return 0..<max(0, paperSize.width - leftMargin - Self.minimumPrintSize.width)
    }

    var validTopMarginRange: Range<CGFloat> {
        return 0..<max(0, paperSize.height - bottomMargin - Self.minimumPrintSize.height)
    }

    var validBottomMarginRange: Range<CGFloat> {
        return 0..<max(0, paperSize.height - topMargin - Self.minimumPrintSize.height)
    }

    var shouldPrintBackgrounds: Bool {
        get {
            self[.shouldPrintBackgrounds] as? Bool ?? false
        }
        set {
            self[.shouldPrintBackgrounds] = newValue
        }
    }

    var shouldPrintHeadersAndFooters: Bool {
        get {
            self[.printHeadersAndFooters] as? Bool ?? true
        }
        set {
            self[.printHeadersAndFooters] = newValue
        }
    }

    subscript (key: NSPrintInfo.AttributeKey) -> Any? {
        get {
            self.dictionary()[key.rawValue]
        }
        set {
            self.dictionary()[key.rawValue] = newValue
        }
    }

    func validMarginRange(for keyPath: ReferenceWritableKeyPath<NSPrintInfo, CGFloat>) -> Range<CGFloat> {
        switch keyPath {
        case \.leftMargin: validLeftMarginRange
        case \.rightMargin: validRightMarginRange
        case \.topMargin: validTopMarginRange
        case \.bottomMargin: validBottomMarginRange
        default: fatalError("Invalid keyPath")
        }
    }

}

extension NSPrintInfo.AttributeKey {
    static let shouldPrintBackgrounds = Self(rawValue: "ShouldPrintBackgrounds")
    static let printHeadersAndFooters = Self(rawValue: "PrintHeadersAndFooters")
}
