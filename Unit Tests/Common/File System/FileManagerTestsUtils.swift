//
//  FileManagerTestsUtils.swift
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
import XCTest

// File Manager cleaning up temp directories after test runs
// Automatically loading during test runs by shadowed
// NSFileManager.defaultManager in NSFileManagerTestUtils.m
@objc(TestFileManager)
class TestFileManager: FileManager, XCTestObservation {

    static var defaultFileManager = FileManager()
    static var testFileManager = TestFileManager()
    @objc static override var `default`: FileManager {
        guard NSApp != nil else { return defaultFileManager }
        return testFileManager
    }

    override init() {
        super.init()
        DispatchQueue.main.async {
            XCTestObservationCenter.shared.addTestObserver(self)
        }

    }

    var tempDirectory: URL?
    var createdDirectories: [URL]?

    override func url(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask, appropriateFor url: URL?, create shouldCreate: Bool) throws -> URL {
        let url = try super.url(for: directory, in: domain, appropriateFor: url, create: shouldCreate)
        if case .itemReplacementDirectory = directory {
            createdDirectories?.append(url)
        }
        return url
    }

    override var temporaryDirectory: URL {
        let temporaryDirectory = super.temporaryDirectory
        guard createdDirectories != nil else { return temporaryDirectory }

        if let tempDirectory {
            return tempDirectory
        }
        let url = temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! super.createDirectory(at: url, withIntermediateDirectories: true)
        createdDirectories!.append(url)
        tempDirectory = url
        return url
    }

    func testCaseWillStart(_ testCase: XCTestCase) {
        createdDirectories = []
    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
        for url in self.createdDirectories ?? [] {
            try? self.removeItem(at: url)
        }
        createdDirectories = nil
        tempDirectory = nil
    }
}
