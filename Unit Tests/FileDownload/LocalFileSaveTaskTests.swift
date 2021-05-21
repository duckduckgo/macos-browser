//
//  LocalFileSaveTaskTests.swift
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

final class LocalFileSaveTaskTests: XCTestCase {
    var taskDelegate: FileDownloadTaskDelegateMock! // swiftlint:disable:this weak_delegate
    let testFile = "downloaded file"
    let testData = "test file contents".data(using: .utf8)!
    let fm = FileManager.default

    override func setUp() {
        taskDelegate = FileDownloadTaskDelegateMock()
        let tempDir = fm.temporaryDirectory
        for file in (try? fm.contentsOfDirectory(atPath: tempDir.path)) ?? [] where file.hasPrefix(testFile) {
            try? fm.removeItem(at: tempDir.appendingPathComponent(file))
        }

    }

    func testWhenTaskStartedDestinationURLIsQueried() {
        let task = LocalFileSaveTask(download: FileDownloadRequestMock.download(nil, prompt: false),
                                     url: URL(fileURLWithPath: ""),
                                     fileType: .pdf)

        let e = expectation(description: "destinationURLCallback called")
        taskDelegate.destinationURLCallback = { t, callback in
            XCTAssertTrue(t === task)
            XCTAssertEqual(t.fileTypes, [.pdf])
            e.fulfill()

            callback(nil, nil)
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 0.1)
    }

    func testWhenTaskDestinationURLCallbackIsCancelledThenTaskIsCancelled() {
        let task = LocalFileSaveTask(download: FileDownloadRequestMock.download(nil, prompt: false),
                                     url: URL(fileURLWithPath: ""),
                                     fileType: .pdf)

        taskDelegate.destinationURLCallback = { _, callback in
            callback(nil, nil)
        }
        let e = expectation(description: "destinationURLCallback called")
        taskDelegate.downloadDidFinish = { t, result in
            XCTAssertTrue(t === task)
            if case .failure(.cancelled) = result {} else {
                XCTFail("unexpected result")
            }
            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 0.1)
    }

    func testWhenCopyFailsThenTaskFailsWithError() {
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        let task = LocalFileSaveTask(download: FileDownloadRequestMock.download(nil, prompt: false),
                                     url: URL(fileURLWithPath: "/test/file"),
                                     fileType: .pdf)

        taskDelegate.destinationURLCallback = { _, callback in
            callback(destURL, nil)
        }
        let e = expectation(description: "destinationURLCallback called")
        taskDelegate.downloadDidFinish = { t, result in
            XCTAssertTrue(t === task)
            if case .failure(.failedToMoveFileToDownloads) = result {} else {
                XCTFail("unexpected result")
            }
            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 0.1)
    }

    func testWhenDestinationFileExistsThenNumberIsIncreased() throws {
        let srcFile = fm.temporaryDirectory.appendingPathComponent(testFile + ".test")
        fm.createFile(atPath: srcFile.path, contents: testData, attributes: nil)
        let existingURL = fm.temporaryDirectory.appendingPathComponent(testFile + " 1.test")
        fm.createFile(atPath: existingURL.path, contents: nil, attributes: nil)
        let expectedURL = fm.temporaryDirectory.appendingPathComponent(testFile + " 2.test")
        let task = LocalFileSaveTask(download: FileDownloadRequestMock.download(nil, prompt: false),
                                     url: srcFile,
                                     fileType: nil)

        taskDelegate.destinationURLCallback = { _, callback in
            callback(srcFile, nil)
        }
        let e = expectation(description: "destinationURLCallback called")
        taskDelegate.downloadDidFinish = { t, result in
            XCTAssertTrue(t === task)
            if case .success(expectedURL) = result {} else {
                XCTFail("unexpected result")
            }
            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 0.1)
        XCTAssertTrue(fm.fileExists(atPath: srcFile.path))
        XCTAssertTrue(fm.fileExists(atPath: existingURL.path))
        XCTAssertTrue(fm.fileExists(atPath: expectedURL.path))

        XCTAssertEqual(try Data(contentsOf: srcFile), testData)
        XCTAssertEqual(try Data(contentsOf: expectedURL), testData)
        XCTAssertNotEqual(try Data(contentsOf: existingURL), testData)
    }

}
