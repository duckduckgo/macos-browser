//
//  DownloadsIntegrationTests.swift
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

import Combine
import Common
import XCTest
@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
class DownloadsIntegrationTests: XCTestCase {

    struct DataSource {
        let testData = "HelloWorld!".utf8data
        let html = "<html><body>some data</body></html>".utf8data
    }

    let data = DataSource()
    static var window: NSWindow!
    var tabViewModel: TabViewModel {
        (Self.window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
    }

    @MainActor
    override class func setUp() {
        window = WindowsManager.openNewWindow(with: .none)!
    }

    override class func tearDown() {
        window.close()
        window = nil
    }

    // MARK: - Tests
    // Uses tests-server helper tool for mocking HTTP requests (see tests-server/main.swift)

    @MainActor
    func testWhenShouldDownloadResponse_downloadStarts() async throws {
        var persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.selectedDownloadLocation = FileManager.default.temporaryDirectory.absoluteString

        let downloadTaskFuture = FileDownloadManager.shared.downloadsPublisher.timeout(5).first().promise()
        let suffix = Int.random(in: 0..<Int.max)
        let url = URL.testsServer
            .appendingPathComponent("fname_\(suffix).dat")
            .appendingTestParameters(data: data.html,
                                     headers: ["Content-Disposition": "attachment; filename=\"fname_\(suffix).dat\"",
                                               "Content-Type": "text/html"])
        let tab = tabViewModel.tab
        _=await tab.setUrl(url, userEntered: nil)?.value?.result

        let fileUrl = try await downloadTaskFuture.get().output
            .timeout(1, scheduler: DispatchQueue.main) { .init(TimeoutError() as NSError, isRetryable: false) }.first().promise().get()

        XCTAssertEqual(fileUrl, FileManager.default.temporaryDirectory.appendingPathComponent("fname_\(suffix).dat"))
        XCTAssertEqual(try? Data(contentsOf: fileUrl), data.html)
    }

    @MainActor
    func testWhenNavigationActionIsData_downloadStarts() async throws {
        var persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.selectedDownloadLocation = FileManager.default.temporaryDirectory.absoluteString

        let tab = tabViewModel.tab
        // load empty page
        let pageUrl = URL.testsServer.appendingTestParameters(data: data.html)
        _=await tab.setUrl(pageUrl, userEntered: nil)?.value?.result

        let downloadTaskFuture = FileDownloadManager.shared.downloadsPublisher.timeout(5).first().promise()
        let suffix = Int.random(in: 0..<Int.max)
        let js = """
        (function() {
            var link = document.createElement("a");
            link.href = 'data:application/octet-stream;charset=utf-8,\(data.testData.utf8String()!)';
            link.download = "helloWorld_\(suffix).txt";
            link.target = "_blank";
            link.click();
            document.body.appendChild(link);
            return true;
        })();
        """
        try! await tab.webView.evaluateJavaScript(js)

        let fileUrl = try await downloadTaskFuture.get().output
            .timeout(5, scheduler: DispatchQueue.main) { .init(TimeoutError() as NSError, isRetryable: false) }.first().promise().get()

        XCTAssertEqual(fileUrl, FileManager.default.temporaryDirectory.appendingPathComponent("helloWorld_\(suffix).txt"))
        XCTAssertEqual(try? Data(contentsOf: fileUrl), data.testData)
    }

    @MainActor
    func testWhenNavigationActionIsBlob_downloadStarts() async throws {
        // test failure
        (["a"] as NSArray).perform(NSSelectorFromString("UTF8String"))

        var persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.selectedDownloadLocation = FileManager.default.temporaryDirectory.absoluteString

        let tab = tabViewModel.tab
        // load empty page
        let pageUrl = URL.testsServer.appendingTestParameters(data: data.html)
        _=await tab.setUrl(pageUrl, userEntered: nil)?.value?.result

        let downloadTaskFuture = FileDownloadManager.shared.downloadsPublisher.timeout(5).first().promise()
        let suffix = Int.random(in: 0..<Int.max)
        let js = """
        (function() {
            var blob = new Blob(['\(data.testData.utf8String()!)'], { type: 'application/octet-stream' });
            var link = document.createElement("a");
            link.href = URL.createObjectURL(blob);
            link.download = "blobdload_\(suffix).json";
            link.target = "_blank";
            link.click();
            document.body.appendChild(link);
            return true;
        })();
        """
        try! await tab.webView.evaluateJavaScript(js)

        let fileUrl = try await downloadTaskFuture.get().output
            .timeout(1, scheduler: DispatchQueue.main) { .init(TimeoutError() as NSError, isRetryable: false) }.first().promise().get()

        XCTAssertEqual(fileUrl, FileManager.default.temporaryDirectory.appendingPathComponent("blobdload_\(suffix).json"))
        XCTAssertEqual(try? Data(contentsOf: fileUrl), data.testData)
    }

}
