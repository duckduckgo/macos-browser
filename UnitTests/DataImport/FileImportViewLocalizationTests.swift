//
//  FileImportViewLocalizationTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import XCTest
import SwiftUI
@testable import DuckDuckGo_Privacy_Browser
import BrowserServicesKit

@available(macOS 13.0, *)
class FileImportViewLocalizationTests: XCTestCase {

    override func tearDown() {
        Bundle.resetSwizzling()
        customAssert = nil
        customAssertionFailure = nil
    }

    func testFileImportLocalizedStrings() throws {
        // collect reference "Base" localization escaped format arguments
        var referenceValues = [DataImport.Source: [DataImport.DataType: [String]]]()
        for locale in [.base] + Bundle.main.availableLocalizations().filter({ $0 != .base }) {
            // swizzle "locale".lproj bundle
            setLocale(locale)

            for source in DataImport.Source.allCases {
                for dataType in source.supportedDataTypes {
                    let e = expectation(description: "Button item should not be missing")
                    // build instructions
                    let items = fileImportInstructionsBuilder(source: source, dataType: dataType) { title in
                        // button title should not be empty
                        XCTAssertFalse(title.isEmpty, "\(locale).\(source.rawValue).\(dataType.rawValue).title")
                        // button should be present in items
                        e.fulfill()
                        return AnyView(EmptyView())
                    }
                    waitForExpectations(timeout: 0)

                    // find first .string (format) item
                    let formatItem = items.first
                    guard case .string(let format) = formatItem else {
                        XCTFail("First item should be Format String – \(source.rawValue).\(dataType.rawValue)")
                        continue
                    }

                    // find all %-escaped sequences in the format
                    let formatItemsRegex = /%(?:\d+\$)?(?:lld|ld|d|s|@)/
                    let formatArgs = format.matches(of: formatItemsRegex).enumerated().map { (idx, match) in
                        var value = String(match.output)
                        if !value.contains("\(idx + 1)") {
                            // if escape sequence has no index - insert it (convert %d to %4$d)
                            value.insert(contentsOf: "\(idx + 1)$", at: value.index(after: value.startIndex))
                        }
                        return value
                    }

                    switch locale {
                    case .base:
                        // write Base reference value
                        referenceValues[source, default: [:]][dataType] = formatArgs
                    default:
                        // format args should match but their positions may differ
                        XCTAssertEqual(referenceValues[source]![dataType]!.sorted(), formatArgs.sorted(),
                                       "\(locale).\(source.rawValue).\(dataType.rawValue).formatArgs")
                    }

                    // number of %@ arguments should match number of builder .image and .button arguments
                    XCTAssertEqual(referenceValues[source]![dataType]!.filter { $0.hasSuffix("@") }.count,
                                   items.filter { if case .image = $0 { true } else if case .view = $0 { true } else { false } }.count,
                                   "\(locale).\(source.rawValue).\(dataType.rawValue).imagesAndButtons")

                    // number of %s arguments should match number of builder .string arguments
                    XCTAssertEqual(referenceValues[source]![dataType]!.filter { $0.hasSuffix("s") }.count,
                                   items[1.../* 0 == format */].filter { if case .string = $0 { true } else { false } }.count,
                                   "\(locale).\(source.rawValue).\(dataType.rawValue).strings")

#if CI
                    customAssert = { condition, message, file, line in
                        XCTAssert(condition(), "\(locale).\(source.rawValue).\(dataType.rawValue).InstructionsView.assert: " + message(), file: file, line: line)
                    }
                    customAssertionFailure = { message, file, line in
                        XCTFail("\(locale).\(source.rawValue).\(dataType.rawValue).InstructionsView.assertionFailure: " + message(), file: file, line: line)
                    }
#endif
                    _=InstructionsView {
                        items
                    } // should not assert
                }
            }
        }
    }

    // Helper function to set the application's locale for testing
    private func setLocale(_ identifier: String) {
        let bundlePath = Bundle.mainBundle.path(forResource: identifier, ofType: "lproj")!
        let testBundle = Bundle(path: bundlePath)!
        Bundle.swizzleMainBundle(with: testBundle)
    }
}

extension InstructionsView.InstructionsItem: Hashable, CustomStringConvertible {

    public var description: String {
        switch self {
        case .string(let string): ".string(\"\(string)\")"
        case .image(let image): ".image(\(image.representations.first!))"
        case .view: ".view"
        }
    }

    public static func == (lhs: DuckDuckGo_Privacy_Browser.InstructionsView.InstructionsItem, rhs: DuckDuckGo_Privacy_Browser.InstructionsView.InstructionsItem) -> Bool {
        switch lhs {
        case .string(let value): if case .string(value) = rhs { return true }
        case .image(let value1): if case .image(let value2) = rhs { return value1.tiffRepresentation! == value2.tiffRepresentation }
        case .view: if case .view = rhs { return true }
        }
        return false
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .string:
            hasher.combine(1)
        case .image(let image):
            hasher.combine(2)
            hasher.combine(image.tiffRepresentation!)
        case .view:
            hasher.combine(3)
        }
    }

}

private extension String {
    static let base = "Base"
}

private extension Bundle {

    static var mainBundle: Bundle = .main
    static var testBundle: Bundle?

    func availableLocalizations() -> [String] {
        try! FileManager.default.contentsOfDirectory(atPath: resourcePath!).compactMap {
            guard $0.hasSuffix(".lproj") else { return nil }
            return $0.dropping(suffix: ".lproj")
        }
    }

    static func swizzleMainBundle(with bundle: Bundle) {
        if testBundle == nil {
            mainBundle = Bundle.main
            swizzleMainBundle()
        }

        testBundle = bundle
    }

    static func resetSwizzling() {
        guard testBundle != nil else { return }
        swizzleMainBundle()
    }

    private static func swizzleMainBundle() {
        let originalMethod = class_getClassMethod(self, #selector(getter: Bundle.main))!
        let swizzledMethod = class_getClassMethod(self, #selector(getter: swizzledMain))!

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc dynamic static var swizzledMain: Bundle {
        testBundle!
    }

}
