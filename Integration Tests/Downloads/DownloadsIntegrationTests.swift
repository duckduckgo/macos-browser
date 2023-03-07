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

    struct URLs {
        let local = URL(string: "http://localhost:8084/")!
    }
    struct DataSource {
        let empty = Data()
        let testData = "HelloWorld!".data(using: .utf8)!
        let html = """
            <html>
                <body>
                    some data
                    <a id="navlink" />
                </body>
            </html>
        """.data(using: .utf8)!

    }
    let urls = URLs()
    let data = DataSource()
    static var window: NSWindow!
    var tabViewModel: TabViewModel {
        (Self.window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
    }

    override class func setUp() {
        window = WindowsManager.openNewWindow(with: .none)!
    }

    override class func tearDown() {
        window.close()
        window = nil
    }

    // MARK: - Tests

    func testWhenShouldDownloadResponse_downloadStarts() throws {
        var persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.selectedDownloadLocation = FileManager.default.temporaryDirectory.absoluteString

        let e = expectation(description: "download finished")
        var fileUrl: URL!
        let c = FileDownloadManager.shared.downloadsPublisher
            .sink { task in
                var c2: AnyCancellable!
                c2 = task.output.sink { completion in
                    if case .failure(let error) = completion {
                        XCTFail("unexpected \(error)")
                    }
                    e.fulfill()
                    c2.cancel()
                    c2 = nil
                } receiveValue: { value in
                    fileUrl = value
                }
            }

        let url = urls.local
            .appendingPathComponent("fname.dat")
            .appendingTestParameters(data: data.html,
                                     headers: ["Content-Disposition": "attachment; filename=\"fname.dat\"",
                                               "Content-Type": "text/html"])
        let tab = tabViewModel.tab
        tab.setUrl(url, userEntered: false)

        waitForExpectations(timeout: 15)
        withExtendedLifetime(c) {}

        XCTAssertEqual(fileUrl, FileManager.default.temporaryDirectory.appendingPathComponent("fname.dat"))
        XCTAssertEqual(try? Data(contentsOf: fileUrl), data.html)
    }

    func testWhenNavigationActionIsData_downloadStarts() {
        var persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.selectedDownloadLocation = FileManager.default.temporaryDirectory.absoluteString

        let tab = tabViewModel.tab
        if case .url(.blankPage, _) = tab.content {} else {
            let eLoadingDidFinish = expectation(description: "isLoading changes to false")
            let c1 = tabViewModel.$isLoading
                .scan((old: false, new: false)) { (old: $0.new, new: $1) }
                .sink {
                    if $0.old == true && $0.new == false {
                        eLoadingDidFinish.fulfill()
                    }
                }
            tab.setUrl(.blankPage, userEntered: false)
            waitForExpectations(timeout: 5)
            withExtendedLifetime(c1) {}
        }

        let e = expectation(description: "download finished")
        var fileUrl: URL!
        let c2 = FileDownloadManager.shared.downloadsPublisher
            .sink { task in
                var c2: AnyCancellable!
                c2 = task.output.sink { completion in
                    if case .failure(let error) = completion {
                        XCTFail("unexpected \(error)")
                    }
                    e.fulfill()
                    c2.cancel()
                    c2 = nil
                } receiveValue: { value in
                    fileUrl = value
                }
            }

        let js = """
        var link = document.createElement("a");
        link.href = 'data:application/octet-stream;charset=utf-8,\(data.testData.utf8String()!)';
        link.download = "helloWorld.txt";
        link.target = "_blank";
        link.click();
        """
        tab.webView.evaluateJavaScript(js)

        waitForExpectations(timeout: 5)
        withExtendedLifetime(c2) {}

        XCTAssertEqual(fileUrl, FileManager.default.temporaryDirectory.appendingPathComponent("helloWorld.txt"))
        XCTAssertEqual(try? Data(contentsOf: fileUrl), data.testData)
    }

    func testWhenNavigationActionIsBlob_downloadStarts() {
        var persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.selectedDownloadLocation = FileManager.default.temporaryDirectory.absoluteString

        let tab = tabViewModel.tab
        if case .url(.blankPage, _) = tab.content {} else {
            let eLoadingDidFinish = expectation(description: "isLoading changes to false")
            let c1 = tabViewModel.$isLoading
                .scan((old: false, new: false)) { (old: $0.new, new: $1) }
                .sink {
                    if $0.old == true && $0.new == false {
                        eLoadingDidFinish.fulfill()
                    }
                }
            tab.setUrl(.blankPage, userEntered: false)
            waitForExpectations(timeout: 5)
            withExtendedLifetime(c1) {}
        }

        let e = expectation(description: "download finished")
        var fileUrl: URL!
        let c2 = FileDownloadManager.shared.downloadsPublisher
            .sink { task in
                var c2: AnyCancellable!
                c2 = task.output.sink { completion in
                    if case .failure(let error) = completion {
                        XCTFail("unexpected \(error)")
                    }
                    e.fulfill()
                    c2.cancel()
                    c2 = nil
                } receiveValue: { value in
                    fileUrl = value
                }
            }

        let js = """
        var blob = new Blob(['\(data.testData.utf8String()!)'], { type: 'application/octet-stream' });
        var link = document.createElement("a");
        link.href = URL.createObjectURL(blob);
        link.download = "blobdload.json";
        link.target = "_blank";
        link.click();
        """
        tab.webView.evaluateJavaScript(js)

        waitForExpectations(timeout: 5)
        withExtendedLifetime(c2) {}

        XCTAssertEqual(fileUrl, FileManager.default.temporaryDirectory.appendingPathComponent("blobdload.json"))
        XCTAssertEqual(try? Data(contentsOf: fileUrl), data.testData)
    }

}

private extension URL {
    func appendingTestParameters(status: Int? = nil, reason: String? = nil, data: Data? = nil, headers: [String: String]? = nil) -> URL {
        var url = self
        if let status {
            url = url.appendingParameter(name: "status", value: String(status))
        }
        if let reason {
            url = url.appendingParameter(name: "reason", value: reason)
        }
        if let headers {
            let value = URL(string: "/")!.appendingParameters(headers).query!
            url = url.appendingParameter(name: "headers", value: value)
        }
        if let dataStr = data?.utf8String() {
            url = url.appendingParameter(name: "data", value: dataStr)
        } else if let data {
            url = url.appendingParameter(name: "data", value: data.base64EncodedString())
        }
        return url
    }
}
