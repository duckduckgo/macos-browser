//
//  WebKitDownloadsTests.swift
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
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class WebKitDownloadsTests: XCTestCase {

    let fm = FileManager.default
    var wkDownloadDelegate: WebKitDownloadDelegate! // swiftlint:disable:this weak_delegate
    var webView: WKWebView!

    let testFile = "downloaded file"
    
    var onStartDownload: ((FileDownloadRequest,
                           FileDownloadManagerDelegate?,
                           FileDownloadPostflight?) -> FileDownloadTask?)?
    var onDestinationRequested: ((FileDownloadTask, (URL?, UTType?) -> Void) -> Void)?
    var onTaskDidFinish: ((FileDownloadTask, Result<URL, FileDownloadError>) -> Void)?

    override func setUp() {
        webView = WKWebView(frame: CGRect())
        wkDownloadDelegate = WebKitDownloadDelegate(downloadManager: self, postflightAction: .open)
        webView.configuration.setDownloadDelegate(wkDownloadDelegate)
        webView.uiDelegate = self
        webView.navigationDelegate = self

        let tempDir = fm.temporaryDirectory
        for file in (try? fm.contentsOfDirectory(atPath: tempDir.path)) ?? [] where file.hasPrefix(testFile) {
            try? fm.removeItem(at: tempDir.appendingPathComponent(file))
        }
    }

    override func tearDown() {
        wkDownloadDelegate = nil
        webView = nil
        onStartDownload = nil
        onDestinationRequested = nil
        onTaskDidFinish = nil
    }

    func testWebKitDataDownload() throws {
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile)

        let eDownloadStarted = expectation(description: "download started")
        let eDestinationRequested = expectation(description: "download destination requested")
        let eTaskFinished = expectation(description: "download task finished")

        let eCompletion = expectation(description: "download output completion received")
        let eValue = expectation(description: "download output value received")

        var outputCancellable: AnyCancellable!
        self.onStartDownload = { request, delegate, postflight in
            eDownloadStarted.fulfill()
            XCTAssertEqual(postflight, .open)
            XCTAssertTrue(delegate === self)

            guard case FileDownload.wkDownload(let download) = request else { fatalError() }
            let task = WebKitDownloadTask(download: download)

            outputCancellable = task.output.sink { completion in
                eCompletion.fulfill()
                if case .finished = completion {} else {
                    XCTFail("unexpected completion \(completion)")
                }
            } receiveValue: { url in
                eValue.fulfill()
                XCTAssertEqual(url, destURL)
            }

            task.start(delegate: self)
            return task
        }
        self.onDestinationRequested = { task, completion in
            eDestinationRequested.fulfill()
            XCTAssertEqual(task.suggestedFilename, "testfile.xhtml")
            XCTAssertEqual(task.fileTypes, [UTType(mimeType: "text/plain")!])
            completion(destURL, task.fileTypes?.first)
        }
        self.onTaskDidFinish = { _, result in
            if case .success(destURL) = result {} else {
                XCTFail("unexpected result \(result)")
            }
            eTaskFinished.fulfill()
        }

        webView.loadHTMLString(Self.html, baseURL: nil)

        withExtendedLifetime(outputCancellable) {
            waitForExpectations(timeout: 3)
        }

        XCTAssertTrue(fm.fileExists(atPath: destURL.path))
    }

    func testWhenDownloadDestinationExistsThenFileNameIndexIsAppended() throws {
        let existingURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        let expectedURL = fm.temporaryDirectory.appendingPathComponent(testFile + " 1")

        let existingData = "test data".data(using: .utf8)!
        try existingData.write(to: existingURL)

        let eTaskFinished = expectation(description: "download task finished")
        let eCompletion = expectation(description: "download output completion received")
        let eValue = expectation(description: "download output value received")

        var outputCancellable: AnyCancellable!
        self.onStartDownload = { request, delegate, _ in
            guard case FileDownload.wkDownload(let download) = request else { fatalError() }
            let task = WebKitDownloadTask(download: download)

            outputCancellable = task.output.sink { completion in
                eCompletion.fulfill()
                if case .finished = completion {} else {
                    XCTFail("unexpected completion \(completion)")
                }
            } receiveValue: { url in
                eValue.fulfill()
                XCTAssertEqual(url, expectedURL)
            }

            task.start(delegate: self)
            return task
        }
        self.onDestinationRequested = { _, completion in
            completion(existingURL, nil)
        }
        self.onTaskDidFinish = { _, result in
            if case .success(expectedURL) = result {} else {
                XCTFail("unexpected result \(result)")
            }
            eTaskFinished.fulfill()
        }

        webView.loadHTMLString(Self.html, baseURL: nil)

        withExtendedLifetime(outputCancellable) {
            waitForExpectations(timeout: 3)
        }

        XCTAssertEqual(try Data(contentsOf: existingURL), existingData)
        XCTAssertTrue(fm.fileExists(atPath: expectedURL.path))
    }

    func testWhenDownloadDestinationChooserCancelledThenTaskIsCancelled() throws {
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile)

        let eTaskFinished = expectation(description: "download task finished")
        let eCompletion = expectation(description: "download output completion received")

        var outputCancellable: AnyCancellable!
        self.onStartDownload = { request, delegate, _ in
            guard case FileDownload.wkDownload(let download) = request else { fatalError() }
            let task = WebKitDownloadTask(download: download)

            outputCancellable = task.output.sink { completion in
                eCompletion.fulfill()
                if case .failure(.cancelled) = completion {} else {
                    XCTFail("unexpected completion \(completion)")
                }
            } receiveValue: { _ in
                XCTFail("Unexpected receiveValue")
            }

            task.start(delegate: self)
            return task
        }
        self.onDestinationRequested = { _, completion in
            completion(nil, nil)
        }
        self.onTaskDidFinish = { _, result in
            if case .failure(.cancelled) = result {} else {
                XCTFail("unexpected result \(result)")
            }
            eTaskFinished.fulfill()
        }

        webView.loadHTMLString(Self.html, baseURL: nil)

        withExtendedLifetime(outputCancellable) {
            waitForExpectations(timeout: 3)
        }

        XCTAssertFalse(fm.fileExists(atPath: destURL.path))
    }

    func testWhenDownloadTaskCancelledThenTaskIsCancelled() throws {
        let destURL = fm.temporaryDirectory.appendingPathComponent(testFile)

        let eTaskFinished = expectation(description: "download task finished")
        let eCompletion = expectation(description: "download output completion received")

        var outputCancellable: AnyCancellable!
        self.onStartDownload = { request, delegate, _ in
            guard case FileDownload.wkDownload(let download) = request else { fatalError() }
            let task = WebKitDownloadTask(download: download)

            outputCancellable = task.output.sink { completion in
                eCompletion.fulfill()
                if case .failure(.cancelled) = completion {} else {
                    XCTFail("unexpected completion \(completion)")
                }
            } receiveValue: { _ in
                XCTFail("Unexpected receiveValue")
            }

            task.start(delegate: self)
            task.cancel()

            return task
        }
        self.onDestinationRequested = { _, completion in
            completion(destURL, nil)
        }
        self.onTaskDidFinish = { _, result in
            if case .failure(.cancelled) = result {} else {
                XCTFail("unexpected result \(result)")
            }
            eTaskFinished.fulfill()
        }

        webView.loadHTMLString(Self.html, baseURL: nil)

        withExtendedLifetime(outputCancellable) {
            waitForExpectations(timeout: 3)
        }

        XCTAssertFalse(fm.fileExists(atPath: destURL.path))
    }

}

extension WebKitDownloadsTests: WKNavigationDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.request.url?.scheme == "blob" {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

}

extension WebKitDownloadsTests: WKUIDelegate, FileDownloadManagerDelegate {
    func chooseDestination(suggestedFilename: String?,
                           directoryURL: URL?,
                           fileTypes: [UTType],
                           callback: @escaping (URL?, UTType?) -> Void) {
        fatalError()
    }

    func fileIconFlyAnimationOriginalRect(for downloadTask: FileDownloadTask) -> NSRect? {
        return nil
    }
}

extension WebKitDownloadsTests: FileDownloadManagerProtocol {
    func startDownload(_ request: FileDownloadRequest,
                       delegate: FileDownloadManagerDelegate?,
                       postflight: FileDownloadPostflight?) -> FileDownloadTask? {
        self.onStartDownload?(request, delegate, postflight)
    }
}

extension WebKitDownloadsTests: FileDownloadTaskDelegate {
    func fileDownloadTaskNeedsDestinationURL(_ task: FileDownloadTask, completionHandler: @escaping (URL?, UTType?) -> Void) {
        self.onDestinationRequested?(task, completionHandler)
    }

    func fileDownloadTask(_ task: FileDownloadTask, didFinishWith result: Result<URL, FileDownloadError>) {
        self.onTaskDidFinish?(task, result)
    }
}

extension WebKitDownloadsTests {
    private static var html: String {
        """
        <html><head><script>\(Self.saveAsJS)</script></head>
        <body>
            <script>
                saveAs(new window.Blob(["asdf"], { type: "text/plain;charset=utf-8" }), "testfile.xhtml")
            </script>
        </body></html>
        """
    }

    private static let saveAsJS = """
        var saveAs = function(e) {
            "use strict";
            if (typeof e === "undefined" || typeof navigator !== "undefined" && /MSIE [1-9]\\./.test(navigator.userAgent)) {
                return
            }
            var t = e.document,
                n = function() {
                    return e.URL || e.webkitURL || e
                },
                r = t.createElementNS("http://www.w3.org/1999/xhtml", "a"),
                o = "download" in r,
                a = function(e) {
                    var t = new MouseEvent("click");
                    e.dispatchEvent(t)
                },
                i = /constructor/i.test(e.HTMLElement) || e.safari,
                f = /CriOS\\/[\\d]+/.test(navigator.userAgent),
                u = function(t) {
                    (e.setImmediate || e.setTimeout)(function() {
                        throw t
                    }, 0)
                },
                s = "application/octet-stream",
                d = 1e3 * 40,
                c = function(e) {
                    var t = function() {
                        if (typeof e === "string") {
                            n().revokeObjectURL(e)
                        } else {
                            e.remove()
                        }
                    };
                    setTimeout(t, d)
                },
                l = function(e, t, n) {
                    t = [].concat(t);
                    var r = t.length;
                    while (r--) {
                        var o = e["on" + t[r]];
                        if (typeof o === "function") {
                            try {
                                o.call(e, n || e)
                            } catch (a) {
                                u(a)
                            }
                        }
                    }
                },
                p = function(e) {
                    if (/^\\s*(?:text\\/\\S*|application\\/xml|\\S*\\/\\S*\\+xml)\\s*;.*charset\\s*=\\s*utf-8/i.test(e.type)) {
                        return new Blob([String.fromCharCode(65279), e], {
                            type: e.type
                        })
                    }
                    return e
                },
                v = function(t, u, d) {
                    if (!d) {
                        t = p(t)
                    }
                    var v = this,
                        w = t.type,
                        m = w === s,
                        y,
                        h = function() {
                            l(v, "writestart progress write writeend".split(" "))
                        },
                        S = function() {
                            if ((f || m && i) && e.FileReader) {
                                var r = new FileReader;
                                r.onloadend = function() {
                                    var t = f ? r.result : r.result.replace(/^data:[^;]*;/, "data:attachment/file;");
                                    var n = e.open(t, "_blank");
                                    if (!n)
                                        e.location.href = t;
                                    t = undefined;
                                    v.readyState = v.DONE;
                                    h()
                                };
                                r.readAsDataURL(t);
                                v.readyState = v.INIT;
                                return
                            }
                            if (!y) {
                                y = n().createObjectURL(t)
                            }
                            if (m) {
                                e.location.href = y
                            } else {
                                var o = e.open(y, "_blank");
                                if (!o) {
                                    e.location.href = y
                                }
                            }
                            v.readyState = v.DONE;
                            h();
                            c(y)
                        };
                    v.readyState = v.INIT;
                    if (o) {
                        y = n().createObjectURL(t);
                        setTimeout(function() {
                            r.href = y;
                            r.download = u;
                            a(r);
                            h();
                            c(y);
                            v.readyState = v.DONE
                        });
                        return
                    }
                    S()
                },
                w = v.prototype,
                m = function(e, t, n) {
                    return new v(e, t || e.name || "download", n)
                };
            if (typeof navigator !== "undefined" && navigator.msSaveOrOpenBlob) {
                return function(e, t, n) {
                    t = t || e.name || "download";
                    if (!n) {
                        e = p(e)
                    }
                    return navigator.msSaveOrOpenBlob(e, t)
                }
            }
            w.abort = function() {};
            w.readyState = w.INIT = 0;
            w.WRITING = 1;
            w.DONE = 2;
            w.error = w.onwritestart = w.onprogress = w.onwrite = w.onabort = w.onerror = w.onwriteend = null;
            return m
        }(typeof self !== "undefined" && self || typeof window !== "undefined" && window || this.content);
    """
}
