//
//  WebContentDownloadTaskTests.swift
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

final class WebContentDownloadTaskTests: XCTestCase {
    var taskDelegate: FileDownloadTaskDelegateMock! // swiftlint:disable:this weak_delegate
    var navigationDelegate: WebViewNavigationDelegateMock! // swiftlint:disable:this weak_delegate
    let testFile = "downloaded file"
    let testHtml = "<html><head><title>*** Title ***</title></head><body>test content</body></html>"
    var webView: WKWebView!
    let fm = FileManager.default

    override func setUp() {
        taskDelegate = FileDownloadTaskDelegateMock()
        let tempDir = fm.temporaryDirectory
        for file in (try? fm.contentsOfDirectory(atPath: tempDir.path)) ?? [] where file.hasPrefix(testFile) {
            try? fm.removeItem(at: tempDir.appendingPathComponent(file))
        }
        webView = WKWebView(frame: CGRect())
        navigationDelegate = WebViewNavigationDelegateMock(e: expectation(description: "HTML loaded"))
        webView.navigationDelegate = navigationDelegate
        webView.loadHTMLString(testHtml, baseURL: nil)
        waitForExpectations(timeout: 3)
    }

    func testWhenTaskStartedDestinationURLIsQueried() {
        let task = WebContentDownloadTask(download: FileDownloadRequestMock.download(nil, prompt: false),
                                          webView: webView)

        let e = expectation(description: "destinationURLCallback called")
        taskDelegate.destinationURLCallback = { t, callback in
            XCTAssertTrue(t === task)
            XCTAssertEqual(t.fileTypes, [.html, .webArchive, .pdf])
            e.fulfill()

            callback(nil, nil)
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 0.1)
    }

    func testWhenTaskDestinationURLCallbackIsCancelledThenTaskIsCancelled() {
        let task = WebContentDownloadTask(download: FileDownloadRequestMock.download(nil, prompt: false),
                                          webView: webView)

        taskDelegate.destinationURLCallback = { _, callback in
            callback(nil, nil)
        }
        let e = expectation(description: "destinationURLCallback called")
        taskDelegate.downloadDidFinish = { t, result in
            XCTAssertTrue(t === task)
            if case .failure(.cancelled) = result {} else {
                XCTFail("unexpected result \(result)")
            }
            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 0.1)
    }

    func testWhenWriteFailsThenTaskFailsWithError() {
        let destURL = URL(fileURLWithPath: "/test/file")
        let task = WebContentDownloadTask(download: FileDownloadRequestMock.download(nil, prompt: false),
                                          webView: webView)

        taskDelegate.destinationURLCallback = { _, callback in
            callback(destURL, .html)
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

        waitForExpectations(timeout: 0.1)
    }

    func testWhenContentsSavedAsHtmlThenDataIsValid() throws {
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile)

        let task = WebContentDownloadTask(download: FileDownloadRequestMock.download(nil, prompt: false),
                                          webView: webView)

        taskDelegate.destinationURLCallback = { _, callback in
            callback(destURL, .html)
        }
        let e = expectation(description: "destinationURLCallback called")
        taskDelegate.downloadDidFinish = { _, _ in
            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 3)
        XCTAssertEqual(try Data(contentsOf: destURL), testHtml.data(using: .utf8))
    }

    func testWhenContentsSavedAsWebArchiveThenDataIsValid() throws {
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile)

        let task = WebContentDownloadTask(download: FileDownloadRequestMock.download(nil, prompt: false),
                                          webView: webView)

        taskDelegate.destinationURLCallback = { _, callback in
            callback(destURL, .webArchive)
        }
        let e = expectation(description: "destinationURLCallback called")
        taskDelegate.downloadDidFinish = { _, _ in
            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 3)
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: destURL), options: [], format: nil) as? [String: Any]
        XCTAssertNotNil(plist?["WebMainResource"] as? [String: Any])
    }

    func testWhenContentsSavedAsPDFThenDataIsValid() throws {
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile)

        let task = WebContentDownloadTask(download: FileDownloadRequestMock.download(nil, prompt: false),
                                          webView: webView)

        taskDelegate.destinationURLCallback = { _, callback in
            callback(destURL, .pdf)
        }
        let e = expectation(description: "destinationURLCallback called")
        taskDelegate.downloadDidFinish = { _, _ in
            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 3)

        let data = try Data(contentsOf: destURL)
        XCTAssertTrue(data.prefix(through: 3) == "%PDF".data(using: .utf8))
    }

    func testWhenDestinationFileExistsThenNumberIsIncreased() {
        let existingURL = fm.temporaryDirectory.appendingPathComponent(testFile + ".test")
        fm.createFile(atPath: existingURL.path, contents: nil, attributes: nil)
        let expectedURL = fm.temporaryDirectory.appendingPathComponent(testFile + " 1.test")

        let task = WebContentDownloadTask(download: FileDownloadRequestMock.download(nil, prompt: false),
                                          webView: webView)

        taskDelegate.destinationURLCallback = { _, callback in
            callback(existingURL, .html)
        }
        let e = expectation(description: "destinationURLCallback called")
        taskDelegate.downloadDidFinish = { t, result in
            XCTAssertTrue(t === task)
            if case .success(expectedURL) = result {} else {
                XCTFail("unexpected result \(result)")
            }
            e.fulfill()
        }

        task.start(delegate: taskDelegate)

        waitForExpectations(timeout: 3)
    }

}

final class WebViewNavigationDelegateMock: NSObject, WKNavigationDelegate {
    let e: XCTestExpectation
    init(e: XCTestExpectation) {
        self.e = e
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        e.fulfill()
    }
}
