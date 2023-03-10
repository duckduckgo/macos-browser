//
//  UTTypeTests.swift
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
import XCTest
@testable import DuckDuckGo_Privacy_Browser

class UTTypeTests: XCTestCase {

    func testStaticUTTypesExtensions() {
        XCTAssertEqual(UTType.html.fileExtension, "html")
        XCTAssertEqual(UTType.jpeg.fileExtension, "jpeg")
        XCTAssertEqual(UTType.pdf.fileExtension, "pdf")
        XCTAssertEqual(UTType.webArchive.fileExtension, "webarchive")
        XCTAssertEqual(UTType(fileExtension: "asdasdasd")!.fileExtension, "asdasdasd")
    }

    func testInitWithExtensions() {
        XCTAssertEqual(UTType(fileExtension: "pdf"), UTType.pdf)
        XCTAssertEqual(UTType(fileExtension: "htm"), UTType.html)
        XCTAssertEqual(UTType(fileExtension: "html"), UTType.html)
        XCTAssertEqual(UTType(fileExtension: "jpeg"), UTType.jpeg)
        XCTAssertEqual(UTType(fileExtension: "jpg"), UTType.jpeg)
        XCTAssertEqual(UTType(fileExtension: "webArchive"), UTType.webArchive)
        XCTAssertEqual(UTType(fileExtension: "webarchive"), UTType.webArchive)
    }

    func testInitWithMimeTypes() {
        XCTAssertEqual(UTType(mimeType: "text/html"), UTType.html)
        XCTAssertEqual(UTType(mimeType: "application/pdf"), UTType.pdf)
        XCTAssertEqual(UTType(mimeType: "image/jpeg"), UTType.jpeg)
    }

    func testMimeTypes() {
        XCTAssertEqual(UTType.html.mimeType, "text/html")
        XCTAssertEqual(UTType.pdf.mimeType, "application/pdf")
        XCTAssertEqual(UTType.jpeg.mimeType, "image/jpeg")
    }

    func testDescription() {
        for type in [UTType.html, .pdf, .jpeg, .webArchive] {
            XCTAssertFalse(type.description!.isEmpty)
        }
    }

    func testIcon() {
        var prevIcon: NSImage?
        for type in [UTType.html, .pdf, .jpeg, .webArchive] {
            let icon = type.icon
            XCTAssertNotEqual(icon, prevIcon)
            prevIcon = icon
        }
    }

}
