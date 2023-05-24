//
//  FileManagerExtensionTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class FileManagerExtensionTests: XCTestCase {

    let testFile = "the file"
    let testExtension1 = "dmg"
    let testExtension2 = "zip"
    let testData = "test".data(using: .utf8)!
    let fm = FileManager.default

    func testWhenItemMovedToSameURLIncrementingIndexThenNoErrorIsThrown() {
        let srcURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        try? testData.write(to: srcURL)

        let destURL = try? fm.moveItem(at: srcURL, to: srcURL, incrementingIndexIfExists: true)
        XCTAssertEqual(srcURL, destURL)
        XCTAssertTrue(fm.fileExists(atPath: destURL!.path))
    }

    func testWhenItemMovedToSameURLNotIncrementingIndexThenNoErrorIsThrown() {
        let srcURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        try? testData.write(to: srcURL)

        let destURL = try? fm.moveItem(at: srcURL, to: srcURL, incrementingIndexIfExists: false)
        XCTAssertEqual(srcURL, destURL)
        XCTAssertTrue(fm.fileExists(atPath: destURL!.path))
    }

    func testWhenItemMoveDestDoesNotExistThenIndexNotIncremented() {
        let srcURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile + testFile)
        try? testData.write(to: srcURL)

        let result = try? fm.moveItem(at: srcURL, to: destURL, incrementingIndexIfExists: true)
        XCTAssertEqual(result, destURL)
        XCTAssertTrue(fm.fileExists(atPath: result!.path))
        XCTAssertFalse(fm.fileExists(atPath: srcURL.path))
    }

    func testWhenItemMoveDestExistsThenIndexIsIncremented() {
        let srcURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        let existingURL1 = fm.temporaryDirectory.appendingPathComponent(testFile + testFile)
        let existingURL2 = fm.temporaryDirectory.appendingPathComponent(testFile + testFile + " 1")
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile + testFile + " 2")

        try? testData.write(to: srcURL)
        try? testData.write(to: existingURL1)
        try? testData.write(to: existingURL2)

        let result = try? fm.moveItem(at: srcURL, to: existingURL1, incrementingIndexIfExists: true)
        XCTAssertEqual(result, destURL)
        XCTAssertTrue(fm.fileExists(atPath: result!.path))
        XCTAssertFalse(fm.fileExists(atPath: srcURL.path))
    }

    func testWhenItemWithExtensionMoveDestExistsThenIndexIsIncrementedBeforeExtension() {
        let srcURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        let existingURL = fm.temporaryDirectory.appendingPathComponent(testFile + testFile)
            .appendingPathExtension(testExtension1)
            .appendingPathExtension(testExtension2)
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile + testFile + "." + testExtension1 + " 1")
            .appendingPathExtension(testExtension2)

        try? testData.write(to: srcURL)
        try? testData.write(to: existingURL)

        let result = try? fm.moveItem(at: srcURL, to: existingURL, incrementingIndexIfExists: true)
        XCTAssertEqual(result, destURL)
        XCTAssertTrue(fm.fileExists(atPath: result!.path))
    }

    func testWhenItemWithExtensionMoveDestExistsAndExtensionProvidedThenIndexIsIncrementedBeforeExtension() {
        let srcURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        let existingURL = fm.temporaryDirectory.appendingPathComponent(testFile + testFile)
            .appendingPathExtension(testExtension1)
            .appendingPathExtension(testExtension2)
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile + testFile + "." + testExtension1 + " 1")
            .appendingPathExtension(testExtension2)

        try? testData.write(to: srcURL)
        try? testData.write(to: existingURL)

        let result = try? fm.moveItem(at: srcURL, to: existingURL, incrementingIndexIfExists: true, pathExtension: testExtension2)
        XCTAssertEqual(result, destURL)
        XCTAssertTrue(fm.fileExists(atPath: result!.path))
    }

    func testWhenItemWithExtensionMoveDestExistsAndDoubleExtensionProvidedThenIndexIsIncrementedBeforeDoubleExtension() {
        let srcURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        let existingURL = fm.temporaryDirectory.appendingPathComponent(testFile + testFile)
            .appendingPathExtension(testExtension1)
            .appendingPathExtension(testExtension2)
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile + testFile + " 1")
            .appendingPathExtension(testExtension1)
            .appendingPathExtension(testExtension2)

        try? testData.write(to: srcURL)
        try? testData.write(to: existingURL)

        let result = try? fm.moveItem(at: srcURL, to: existingURL,
                                      incrementingIndexIfExists: true,
                                      pathExtension: testExtension1 + "." + testExtension2)
        XCTAssertEqual(result, destURL)
        XCTAssertTrue(fm.fileExists(atPath: result!.path))
    }

    func testWhenItemWithExtensionMoveDestExistsAndWrongExtensionProvidedThenIndexIsIncrementedBeforeActualExtension() {
        let srcURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        let existingURL = fm.temporaryDirectory.appendingPathComponent(testFile + testFile)
            .appendingPathExtension(testExtension1)
            .appendingPathExtension("asd")
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile + testFile + "." + testExtension1 + " 1")
            .appendingPathExtension("asd")

        try? testData.write(to: srcURL)
        try? testData.write(to: existingURL)

        let result = try? fm.moveItem(at: srcURL, to: existingURL,
                                      incrementingIndexIfExists: true,
                                      pathExtension: testExtension1)
        XCTAssertEqual(result, destURL)
        XCTAssertTrue(fm.fileExists(atPath: result!.path))
    }

    func testWhenItemMovedToReadOnlyDirThenErrorIsThrown() {
        let srcURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        try? testData.write(to: srcURL)

        let destURL = URL(fileURLWithPath: "/ro_volume_file")

        XCTAssertThrowsError(try fm.moveItem(at: srcURL, to: destURL, incrementingIndexIfExists: true), "should throw error") { (error) in
            XCTAssertTrue((error as? CocoaError)?.code == CocoaError.fileWriteNoPermission
                          || (error as? CocoaError)?.code == CocoaError.fileWriteVolumeReadOnly)
        }
    }

}
