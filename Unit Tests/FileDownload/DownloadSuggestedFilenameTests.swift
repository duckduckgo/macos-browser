//
//  DownloadSuggestedFilenameTests.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import Combine
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import DuckDuckGo_Privacy_Browser

final class DownloadSuggestedFilenameTests: XCTestCase {

    let requestWithFileName = URLRequest(url: URL(string: "https://www.example.com/file.html")!)
    let requestWithPath = URLRequest(url: URL(string: "https://www.example.com/")!)
    let requestWithLongerPath = URLRequest(url: URL(string: "https://www.example.com/Guitar")!)

    // MARK: - LocalFileSaveTask

    func testLocalFileSaveTaskSuggestedFilename() {
        let task = LocalFileSaveTask(download: FileDownloadRequestMock.download(requestWithFileName.url,
                                                                                prompt: false,
                                                                                task: nil),
                                     url: URL(fileURLWithPath: "/local/file.pdf"),
                                     fileType: nil)
        XCTAssertEqual(task.suggestedFilename, "file.pdf")
    }

    // MARK: - DataSaveTask

    func testWhenDataSaveTaskSuggestedFilenameThenSuggestedNameMatches() {
        let task = DataSaveTask(download: FileDownloadRequestMock.download(requestWithFileName.url,
                                                                           prompt: false,
                                                                           task: nil),
                                data: Data(),
                                mimeType: "application/pdf",
                                suggestedFilename: "fn")
        XCTAssertEqual(task.suggestedFilename, "fn")
    }

    func testWhenDataSaveTaskSuggestedFilenameThenSuggestedNameMatchesURLFilename() {
        let task = DataSaveTask(download: FileDownloadRequestMock.download(requestWithFileName.url,
                                                                           prompt: false,
                                                                           task: nil),
                                data: Data(),
                                mimeType: "application/pdf",
                                suggestedFilename: nil)
        XCTAssertEqual(task.suggestedFilename, requestWithFileName.url!.lastPathComponent + ".pdf")
    }

    func testWhenDataSaveTaskHasNoSuggestedFilenameThenSuggestedNameIsGeneratedFromURL() {
        let task = DataSaveTask(download: FileDownloadRequestMock.download(requestWithPath.url,
                                                                           prompt: false,
                                                                           task: nil),
                                data: Data(),
                                mimeType: "application/zip",
                                suggestedFilename: nil)
        XCTAssertEqual(task.suggestedFilename, "example_com.zip")
    }

    func testWhenDataSaveTaskHasNoSuggestedFilenameThenSuggestedNameIsGeneratedFromURLLastPathComponent() {
        let task = DataSaveTask(download: FileDownloadRequestMock.download(requestWithLongerPath.url,
                                                                           prompt: false,
                                                                           task: nil),
                                data: Data(),
                                mimeType: "application/zip",
                                suggestedFilename: nil)
        XCTAssertEqual(task.suggestedFilename, "Guitar.zip")
    }

    func testWhenDataSaveTaskHasNoSuggestedFilenameAndURLIsEmptyThenSuggestedNameIsDefault() {
        let task = DataSaveTask(download: FileDownloadRequestMock.download(URL(string: "https://"), prompt: false, task: nil),
                                data: Data(),
                                mimeType: "application/zip",
                                suggestedFilename: nil)
        XCTAssertEqual(task.suggestedFilename, "Unknown.zip")
    }

    // MARK: - WebContentDownloadTask

    func testWhenWebPageHasTitleThenWebContentDownloadTaskUsesTitleAsFilename() {
        let webView = WKWebView(frame: CGRect())
        let navigationDelegate = TestNavigationDelegate(e: expectation(description: "HTML loaded"))
        webView.navigationDelegate = navigationDelegate
        webView.loadHTMLString("<html><head><title>** it's\\a/[\"/title\"]!</title></head><body></body></html>", baseURL: requestWithFileName.url)
        waitForExpectations(timeout: 3)

        let task = WebContentDownloadTask(download: FileDownloadRequestMock.download(requestWithFileName.url, prompt: false, task: nil),
                                          webView: webView)
        XCTAssertEqual(task.suggestedFilename, "__ it's_a____title__!.html")
    }

    func testWhenWebPageHasNoTitleThenWebContentDownloadTaskGeneratesFilenameFromURL() {
        let webView = WKWebView(frame: CGRect())
        let navigationDelegate = TestNavigationDelegate(e: expectation(description: "HTML loaded"))
        webView.navigationDelegate = navigationDelegate
        webView.loadHTMLString("<html><body></body></html>", baseURL: requestWithFileName.url)
        waitForExpectations(timeout: 3)

        let task = WebContentDownloadTask(download: FileDownloadRequestMock.download(requestWithFileName.url, prompt: false, task: nil),
                                          webView: webView)
        XCTAssertEqual(task.suggestedFilename, "file.html")
    }

    // MARK: - URLRequestDownloadTask

    func testWhenDispositionProvidedThenURLRequestDownloadTaskReturnsFilename() {
        let task = URLRequestDownloadTask(download: .request(requestWithLongerPath, suggestedName: nil, promptForLocation: false),
                                          request: requestWithLongerPath)

        stub(condition: { _ in true }, response: { _ -> HTTPStubsResponse in
            HTTPStubsResponse(data: Data(),
                              statusCode: 200,
                              headers: ["Content-Disposition": "attachment; filename=\"test.zip\""])
        })

        let e = expectation(description: "destinationURLCallback called")
        let taskDelegate = FileDownloadTaskDelegateMock()
        taskDelegate.destinationURLCallback = { t, callback in
            XCTAssertEqual(t.suggestedFilename, "test.zip")
            e.fulfill()

            callback(nil, nil)
        }

        task.start(delegate: taskDelegate)

        withExtendedLifetime(taskDelegate) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenNoDispositionThenURLRequestDownloadTaskGeneratetsFilenameFromURL() {
        let task = URLRequestDownloadTask(download: .request(requestWithLongerPath, suggestedName: nil, promptForLocation: false),
                                          request: requestWithLongerPath)

        stub(condition: { _ in true }, response: { _ -> HTTPStubsResponse in
            HTTPStubsResponse(data: Data(), statusCode: 200, headers: ["Content-Type": "application/zip"])
        })

        let e = expectation(description: "destinationURLCallback called")
        let taskDelegate = FileDownloadTaskDelegateMock()
        taskDelegate.destinationURLCallback = { t, callback in
            XCTAssertEqual(t.suggestedFilename, "Guitar.zip")
            e.fulfill()

            callback(nil, nil)
        }

        task.start(delegate: taskDelegate)

        withExtendedLifetime(taskDelegate) {
            waitForExpectations(timeout: 1)
        }
    }

}
