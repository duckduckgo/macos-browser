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

class YourLocalizationTests: XCTestCase {

    override func tearDown() {
        Bundle.resetSwizzling()
    }

    func testLocalizedStringForEnglish() {
        var referenceValues = [DataImport.Source: [DataImport.DataType: [InstructionsView.InstructionsItem]]]()
        for locale in [.base] + Bundle.main.availableLocalizations().filter({ $0 != .base }) {
            setLocale(locale)

            for source in DataImport.Source.allCases {
                for dataType in source.supportedDataTypes {
                    let e = expectation(description: "button factory called")
                    let items = fileImportInstructionsBuilder(source: source, dataType: dataType) { title in
                        XCTAssertFalse(title.isEmpty)
                        e.fulfill()
                        return AnyView(EmptyView())
                    }
                    waitForExpectations(timeout: 0)

                    if locale == .base {
                        referenceValues[source, default: [:]][dataType, default: []] = items
                    } else {
                        XCTAssertEqual(Set(referenceValues[source]![dataType]!), Set(items), "\(locale).\(source.rawValue).\(dataType.rawValue)")
                    }
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
        case .string: if case .string = rhs { return true }
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
