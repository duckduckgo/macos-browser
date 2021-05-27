//
//  URLRequestDownloadTaskTests.swift
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
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import DuckDuckGo_Privacy_Browser

// swiftlint:disable type_body_length
final class URLRequestDownloadTaskTests: XCTestCase {

    var taskDelegate: FileDownloadTaskDelegateMock! // swiftlint:disable:this weak_delegate
    let testRequest = URLRequest(url: URL(string: "duckduckgo.com")!)
    let testFile = "downloaded file"
    let testData = Data(count: 9000)
    let fm = FileManager.default

    override func setUp() {
        taskDelegate = FileDownloadTaskDelegateMock()
        let tempDir = fm.temporaryDirectory
        for file in (try? fm.contentsOfDirectory(atPath: tempDir.path)) ?? [] where file.hasPrefix(testFile) {
            try? fm.removeItem(at: tempDir.appendingPathComponent(file))
        }
    }

    override func tearDown() {
        HTTPStubs.removeAllStubs()
        Progress.restoreUnpublish()
    }

    func testWhenTaskStartedThenDownloadIsStartedAndDestinationURLIsQueried() {
        let task = URLRequestDownloadTask(download: .request(testRequest, suggestedName: nil, promptForLocation: false), request: testRequest)

        let e1 = expectation(description: "request made")
        let e2 = expectation(description: "destinationURLCallback called")
        var requestSent = false
        stub(condition: { request -> Bool in
            XCTAssertEqual(request.url, self.testRequest.url)
            return true
        }, response: { _ -> HTTPStubsResponse in
            usleep(UInt32(0.1 * 1_000_000))
            requestSent = true
            e1.fulfill()
            let response = HTTPStubsResponse(data: self.testData,
                                             statusCode: 200,
                                             headers: ["Content-Disposition": "attachment; filename=\"testname.pdf\"",
                                               "Content-Type": "application/pdf"])
            response.responseTime = 0.3
            return response
        })

        taskDelegate.destinationURLCallback = { t, callback in
            dispatchPrecondition(condition: .onQueue(.main))
            XCTAssertTrue(requestSent)
            XCTAssertTrue(t === task)
            XCTAssertEqual(t.suggestedFilename, "testname.pdf")
            XCTAssertEqual(t.fileTypes, [.pdf])
            XCTAssertEqual(t.progress.totalUnitCount, Int64(self.testData.count))
            XCTAssertEqual(t.progress.completedUnitCount, 0)
            e2.fulfill()

            callback(nil, nil)
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 1)
    }

    func testWhenDownloadedFileIsRemovedThenTaskFails() {
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        let tempURL = destURL.appendingPathExtension(URLRequestDownloadTask.downloadExtension)
        let task = URLRequestDownloadTask(download: .request(testRequest, suggestedName: nil, promptForLocation: false), request: testRequest)

        stub(condition: { _ in true }, response: { _ -> HTTPStubsResponse in
            let response = HTTPStubsResponse(data: self.testData, statusCode: 200, headers: nil)
            response.responseTime = 0.3
            return response
        })

        taskDelegate.destinationURLCallback = { _, callback in
            callback(destURL, nil)

            // remove the .download file for DispatchSource event to be fired
            // and URLRequestTask to be cancelled
            XCTAssertTrue(self.fm.fileExists(atPath: tempURL.path), "temp file does not exist")
            try? self.fm.removeItem(at: tempURL)
        }
        let e = expectation(description: "URLRequestDownloadTask failed")
        taskDelegate.downloadDidFinish = { _, result in
            if case .failure(.cancelled) = result {} else {
                XCTFail("unexpected result \(result)")
            }

            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 2) { error in
            if let error = error {
                XCTFail("failed waiting for expectation \(error)")
            }
        }
    }

    func testWhenDownloadedFileIsRemovedButRequestFinishesThenTaskFails() {
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        let tempURL = destURL.appendingPathExtension(URLRequestDownloadTask.downloadExtension)
        let task = URLRequestDownloadTask(download: .request(testRequest, suggestedName: nil, promptForLocation: false), request: testRequest)

        stub(condition: { _ in true }, response: { _ -> HTTPStubsResponse in
            let response = HTTPStubsResponse(data: self.testData, statusCode: 200, headers: nil)
            // allow destinationURLCallback to finish before the URLSessionTask delivers the response
            response.responseTime = 0.05
            return response
        })

        taskDelegate.destinationURLCallback = { _, callback in
            DispatchQueue.main.async {
                XCTAssertTrue(self.fm.fileExists(atPath: tempURL.path))
                try? self.fm.removeItem(at: tempURL)
            }
            callback(destURL, nil)
        }
        Progress.swizzleUnpublish { progress in
            // simulate delay of DispatchSource FileSystem File Removal event
            // by delaying Progress.unpublish() call delivery
            // to allow URLSessionTask to finish before figuring out the downloaded
            // file had been removed
            usleep(UInt32(0.1 * 1_000_000))
            progress.perform(#selector(Progress.swizzled_unpublish))
        }

        let e = expectation(description: "URLRequestDownloadTask failed")
        taskDelegate.downloadDidFinish = { _, result in
            if case .failure(.failedToMoveFileToDownloads) = result {} else {
                XCTFail("unexpected result \(result)")
            }

            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 1)
    }

    func testWhenDownloadedFileIsRenamedThenFinishesWithNewFileName() {
        let tempDir = (fm.temporaryDirectory as NSURL).fileReferenceURL()!
        let destURL = tempDir.appendingPathComponent(testFile)
        let tempURL = destURL.appendingPathExtension(URLRequestDownloadTask.downloadExtension)
        let expectedURL = tempDir.appendingPathComponent(testFile + "_renamed")
        let tempURL2 = expectedURL.appendingPathExtension(URLRequestDownloadTask.downloadExtension)
        let task = URLRequestDownloadTask(download: .request(testRequest, suggestedName: nil, promptForLocation: false), request: testRequest)

        stub(condition: { _ in true }, response: { _ -> HTTPStubsResponse in
            let response = HTTPStubsResponse(data: self.testData, statusCode: 200, headers: nil)
            response.responseTime = 0.3
            return response
        })

        taskDelegate.destinationURLCallback = { _, callback in
            callback(destURL, nil)
            try? self.fm.moveItem(at: tempURL, to: tempURL2)
        }
        let e = expectation(description: "URLRequestDownloadTask failed")
        taskDelegate.downloadDidFinish = { _, result in
            print("didfinish", CACurrentMediaTime())
            if case .success(expectedURL) = result {} else {
                XCTFail("unexpected result \(result)")
            }

            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 3)
    }

    func testIfRequestFailsThenDestinationURLCallbackNotCalled() {
        let task = URLRequestDownloadTask(download: .request(testRequest, suggestedName: nil, promptForLocation: false), request: testRequest)

        stub(condition: { _ in true }, response: { _ -> HTTPStubsResponse in
            return HTTPStubsResponse(error: NSError(domain: "TestError", code: -1, userInfo: nil))
        })

        let e = expectation(description: "URLRequestDownloadTask failed")
        taskDelegate.downloadDidFinish = { t, result in
            XCTAssertTrue(t === task)
            if case .failure(.failedToCompleteDownloadTask(underlyingError: let error)) = result {
                XCTAssertEqual((error as NSError).domain, "TestError")
            } else {
                XCTFail("unexpected result \(result)")
            }

            e.fulfill()
        }
        taskDelegate.destinationURLCallback = { _, _ in
            XCTFail("unexpected callback")
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 1)
    }

    func testWhenTaskCancelledThenItFails() {
        let task = URLRequestDownloadTask(download: .request(testRequest, suggestedName: nil, promptForLocation: false), request: testRequest)

        stub(condition: { _ in true }, response: { _ -> HTTPStubsResponse in
            return HTTPStubsResponse(data: self.testData, statusCode: 200, headers: nil)
        })

        let e = expectation(description: "URLRequestDownloadTask failed")
        taskDelegate.downloadDidFinish = { t, result in
            XCTAssertTrue(t === task)
            if case .failure(.cancelled) = result {} else {
                XCTFail("unexpected result \(result)")
            }

            e.fulfill()
        }
        taskDelegate.destinationURLCallback = { _, _ in
            XCTFail("unexpected callback")
        }

        task.start(delegate: taskDelegate)
        task.cancel()

        waitForExpectations(timeout: 1)
    }

    func testWhenTaskDestinationURLCallbackIsCancelledThenTaskIsCancelled() {
        let task = URLRequestDownloadTask(download: .request(testRequest, suggestedName: nil, promptForLocation: false), request: testRequest)

        stub(condition: { _ in true }, response: { _ -> HTTPStubsResponse in
            return HTTPStubsResponse(data: self.testData, statusCode: 200, headers: nil)
        })

        let e = expectation(description: "destinationURLCallback called")
        taskDelegate.downloadDidFinish = { _, result in
            if case .failure(.cancelled) = result {} else {
                XCTFail("unexpected result \(result)")
            }
            e.fulfill()
        }
        taskDelegate.destinationURLCallback = { task, callback in
            while task.progress.totalUnitCount == 0 {
                RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            }
            callback(nil, nil)
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 1)
    }

    func testWhenWriteFailsThenTaskFailsWithError() {
        let destURL = URL(fileURLWithPath: "/test/file")
        let task = URLRequestDownloadTask(download: .request(testRequest, suggestedName: nil, promptForLocation: false), request: testRequest)

        stub(condition: { _ in true }, response: { _ -> HTTPStubsResponse in
            return HTTPStubsResponse(data: self.testData, statusCode: 200, headers: nil)
        })

        taskDelegate.destinationURLCallback = { _, callback in
            callback(destURL, nil)
        }
        let e = expectation(description: "destinationURLCallback called")
        taskDelegate.downloadDidFinish = { t, result in
            XCTAssertTrue(t === task)
            if case .failure(.failedToMoveFileToDownloads) = result {} else {
                XCTFail("unexpected result \(result)")
            }
            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 1)
    }

    func testWhenDestinationURLChosenAfterDownloadFinishesAndWriteFailsThenTaskFails() {
        let destURL = URL(fileURLWithPath: "/test/file")

        let task = URLRequestDownloadTask(download: .request(testRequest, suggestedName: nil, promptForLocation: false), request: testRequest)

        stub(condition: { _ in true }, response: { _ -> HTTPStubsResponse in
            return HTTPStubsResponse(data: self.testData, statusCode: 200, headers: nil)
        })

        taskDelegate.destinationURLCallback = { _, callback in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                callback(destURL, nil)
            }
        }
        let e = expectation(description: "downloadDidFinish called")
        taskDelegate.downloadDidFinish = { _, result in
            if case .failure(.failedToMoveFileToDownloads) = result {} else {
                XCTFail("unexpected result \(result)")
            }
            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 1)
    }

    func testWhenDestinationFileExistsThenNumberIsIncreased() {
        let existingURL = fm.temporaryDirectory.appendingPathComponent(testFile + ".test")
        fm.createFile(atPath: existingURL.path, contents: nil, attributes: nil)
        let expectedURL = fm.temporaryDirectory.appendingPathComponent(testFile + " 1.test")

        let task = URLRequestDownloadTask(download: .request(testRequest, suggestedName: nil, promptForLocation: false), request: testRequest)

        stub(condition: { _ in true }, response: { _ -> HTTPStubsResponse in
            return HTTPStubsResponse(data: self.testData, statusCode: 200, headers: nil)
        })

        taskDelegate.destinationURLCallback = { _, callback in
            callback(existingURL, nil)
        }
        let e = expectation(description: "downloadDidFinish called")
        taskDelegate.downloadDidFinish = { t, result in
            XCTAssertTrue(t === task)
            if case .success(expectedURL) = result {} else {
                XCTFail("unexpected result \(result)")
            }
            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 1)
        XCTAssertEqual(try Data(contentsOf: expectedURL), testData)
        XCTAssertNotEqual(try Data(contentsOf: existingURL), testData)
    }

    func testWhenDestinationURLChosenAfterDownloadFinishesThenTaskFinishes() {
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile + ".test")

        let task = URLRequestDownloadTask(download: .request(testRequest, suggestedName: nil, promptForLocation: false), request: testRequest)

        stub(condition: { _ in true }, response: { _ -> HTTPStubsResponse in
            return HTTPStubsResponse(data: self.testData, statusCode: 200, headers: nil)
        })

        taskDelegate.destinationURLCallback = { _, callback in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                callback(destURL, nil)
            }
        }
        let e = expectation(description: "downloadDidFinish called")
        taskDelegate.downloadDidFinish = { t, result in
            XCTAssertTrue(t === task)
            if case .success(destURL) = result {} else {
                XCTFail("unexpected result \(result)")
            }
            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 1)
        XCTAssertEqual(try Data(contentsOf: destURL), testData)
    }

}
// swiftlint:enable type_body_length

private extension Progress {
    private static var swizzledUnpublishBlock: ((Progress) -> Void)?
    private static let lock = NSLock()
    private static var isSwizzled = false
    private static let originalUnpublish = {
        class_getInstanceMethod(Progress.self, #selector(Progress.unpublish))!
    }()
    private static let swizzledUnpublish = {
        class_getInstanceMethod(Progress.self, #selector(Progress.swizzled_unpublish))!
    }()

    static func swizzleUnpublish(with unpublish: @escaping ((Progress) -> Void)) {
        lock.lock()
        defer { lock.unlock() }
        if !self.isSwizzled {
            self.isSwizzled = true
            method_exchangeImplementations(originalUnpublish, swizzledUnpublish)
        }
        self.swizzledUnpublishBlock = unpublish
    }

    static func restoreUnpublish() {
        lock.lock()
        defer { lock.unlock() }
        if self.isSwizzled {
            self.isSwizzled = false
            method_exchangeImplementations(originalUnpublish, swizzledUnpublish)
        }
        self.swizzledUnpublishBlock = nil
    }

    @objc func swizzled_unpublish() {
        Self.lock.lock()
        let swizzledUnpublishBlock = Self.swizzledUnpublishBlock
        Self.lock.unlock()
        swizzledUnpublishBlock?(self) ?? {
            self.unpublish()
        }()
    }
}
