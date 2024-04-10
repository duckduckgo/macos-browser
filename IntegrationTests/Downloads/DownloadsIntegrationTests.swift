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
    var window: NSWindow!
    var tabCollectionViewModel: TabCollectionViewModel!
    var tabViewModel: TabViewModel {
        (window.contentViewController as! MainViewController).browserTabViewController.tabViewModel!
    }

    var contentBlockingMock: ContentBlockingMock!
    var privacyFeaturesMock: AnyPrivacyFeatures!
    var privacyConfiguration: MockPrivacyConfiguration {
        contentBlockingMock.privacyConfigurationManager.privacyConfig as! MockPrivacyConfiguration
    }

    @MainActor
    override func setUp() {
        contentBlockingMock = ContentBlockingMock()
        privacyFeaturesMock = AppPrivacyFeatures(contentBlocking: contentBlockingMock, httpsUpgradeStore: HTTPSUpgradeStoreMock())
        // disable waiting for CBR compilation on navigation
        privacyConfiguration.isFeatureKeyEnabled = { _, _ in
            return false
        }

        tabCollectionViewModel = autoreleasepool {
            TabCollectionViewModel(tabCollection: TabCollection(tabs: [Tab(content: .none, privacyFeatures: privacyFeaturesMock)]))
        }
        window = autoreleasepool {
            WindowsManager.openNewWindow(with: tabCollectionViewModel)!
        }
    }

    @MainActor
    override func tearDown() async throws {
        window?.close()
        window = nil
    }

    // MARK: - Tests
    // Uses tests-server helper tool for mocking HTTP requests (see tests-server/main.swift)

    @MainActor
    func testWhenShouldDownloadResponse_downloadStarts() async throws {
        let preferences = DownloadsPreferences.shared
        preferences.alwaysRequestDownloadLocation = false
        preferences.selectedDownloadLocation = FileManager.default.temporaryDirectory

        let downloadTaskFuture = FileDownloadManager.shared.downloadsPublisher.timeout(5).first().promise()
        let suffix = Int.random(in: 0..<Int.max)
        let url = URL.testsServer
            .appendingPathComponent("fname_\(suffix).dat")
            .appendingTestParameters(data: data.html,
                                     headers: ["Content-Disposition": "attachment; filename=\"fname_\(suffix).dat\"",
                                               "Content-Type": "text/html"])
        let tab = tabViewModel.tab
        _=await tab.setUrl(url, source: .link)?.result

        let fileUrl = try await downloadTaskFuture.get().output
            .timeout(1, scheduler: DispatchQueue.main) { .init(TimeoutError() as NSError) }.first().promise().get()

        XCTAssertEqual(fileUrl, FileManager.default.temporaryDirectory.appendingPathComponent("fname_\(suffix).dat"))
        XCTAssertEqual(try? Data(contentsOf: fileUrl), data.html)
    }

    @MainActor
    func testWhenSaveDialogOpenInBackgroundTabAndTabIsClosed_downloadIsCancelled() async throws {
        let persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.alwaysRequestDownloadLocation = true

        let downloadUrl = URL.testsServer
            .appendingPathComponent("fname.dat")
            .appendingTestParameters(data: data.html,
                                     headers: ["Content-Disposition": "attachment; filename=\"fname.dat\"",
                                               "Content-Type": "text/html"])

        let pageUrl = URL.testsServer
            .appendingTestParameters(data: """
            <html>
            <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Clickable Body</title>
            </head>
            <body onclick="window.open('\(downloadUrl.absoluteString.escapedJavaScriptString())')" style="cursor: pointer;">
            <h1>Click anywhere on the page to open the link</h1>
            </body>
            </html>
            """.utf8data)
        let tab = tabViewModel.tab
        _=await tab.setUrl(pageUrl, source: .link)?.result

        NSApp.activate(ignoringOtherApps: true)
        let downloadTaskFuture = FileDownloadManager.shared.downloadsPublisher.timeout(5).first().promise()

        // click to open a new (download) tab and instantly deactivate it
        let c = tabCollectionViewModel.$selectedTabViewModel.dropFirst()
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [unowned tabCollectionViewModel] tabViewModel in
                tabCollectionViewModel?.select(at: .unpinned(0))
            }
        click(tab.webView)

        // download should start in the background tab
        let downloadTask = try await downloadTaskFuture.get()
        withExtendedLifetime(c) {}

        let downloadTaskOutputPromise = downloadTask.output
            .timeout(1, scheduler: DispatchQueue.main) { .init(TimeoutError() as NSError) }.first().promise()

        // now close the background download tab
        XCTAssertEqual(tabCollectionViewModel.allTabsCount, 2)
        tabCollectionViewModel.remove(at: .unpinned(1))

        do {
            _=try await downloadTaskOutputPromise.value
            XCTFail("download task should‘ve been cancelled")
        } catch FileDownloadError.failedToCompleteDownloadTask(underlyingError: URLError.cancelled?, resumeData: nil, isRetryable: false) {
            // pass
        }
    }

    @MainActor
    func testWhenSaveDialogOpenInBackgroundTabAndWindowIsClosed_downloadIsCancelled() throws {
        var taskCancelledCancellable: AnyCancellable!
        var taskCancelledExpectation: XCTestExpectation!
        let persistor = DownloadsPreferencesUserDefaultsPersistor()
        persistor.alwaysRequestDownloadLocation = true

        autoreleasepool {
            let downloadUrl = URL.testsServer
                .appendingPathComponent("fname.dat")
                .appendingTestParameters(data: data.html,
                                         headers: ["Content-Disposition": "attachment; filename=\"fname.dat\"",
                                                   "Content-Type": "text/html"])

            let pageUrl = URL.testsServer
                .appendingTestParameters(data: """
            <html>
            <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Clickable Body</title>
            </head>
            <body onclick="window.open('\(downloadUrl.absoluteString.escapedJavaScriptString())')" style="cursor: pointer;">
            <h1>Click anywhere on the page to open the link</h1>
            </body>
            </html>
            """.utf8data)
            let tab = tabViewModel.tab
            let ePageLoaded = expectation(description: "Page loaded")
            Task {
                _=await tab.setUrl(pageUrl, source: .link)?.result
                ePageLoaded.fulfill()
            }
            waitForExpectations(timeout: 5)

            NSApp.activate(ignoringOtherApps: true)
            let downloadTaskFuture = FileDownloadManager.shared.downloadsPublisher.timeout(5).first().promise()

            // click to open a new (download) tab and instantly deactivate it
            let c = tabCollectionViewModel.$selectedTabViewModel.dropFirst()
                .first()
                .receive(on: DispatchQueue.main)
                .sink { [unowned tabCollectionViewModel] tabViewModel in
                    tabCollectionViewModel?.select(at: .unpinned(0))
                }
            click(tab.webView)

            // download should start in the background tab
            var downloadTask: WebKitDownloadTask!
            let eDownloadTaskCreated = expectation(description: "Download task created")
            let c2 = downloadTaskFuture.sink { completion in
                if case .failure(let e) = completion {
                    XCTFail("\(e)")
                }
                eDownloadTaskCreated.fulfill()
            } receiveValue: { task in
                downloadTask = task

            }
            waitForExpectations(timeout: 5)
            withExtendedLifetime((c, c2)) {}

            let downloadTaskOutputPromise = downloadTask.output
                .timeout(1, scheduler: DispatchQueue.main) { .init(TimeoutError() as NSError) }.first().promise()

            // now close the window
            tabCollectionViewModel = nil
            window.close()
            window = nil

            taskCancelledExpectation = expectation(description: "Download task should fail with cancelled error")
            taskCancelledCancellable = downloadTaskOutputPromise.sink { completion in
                if case .failure(FileDownloadError.failedToCompleteDownloadTask(underlyingError: URLError.cancelled?, resumeData: nil, isRetryable: false)) = completion {} else {
                    XCTFail("\(completion) – Download task should‘ve been cancelled")
                }
                taskCancelledExpectation.fulfill()
            } receiveValue: { _ in
                XCTFail("Unexpected download success")
            }
        }
        waitForExpectations(timeout: 1)
        withExtendedLifetime(taskCancelledCancellable) {}
    }

    @MainActor
    func testWhenNavigationActionIsData_downloadStarts() async throws {
        let preferences = DownloadsPreferences.shared
        preferences.alwaysRequestDownloadLocation = false
        preferences.selectedDownloadLocation = FileManager.default.temporaryDirectory

        let tab = tabViewModel.tab
        // load empty page
        let pageUrl = URL.testsServer.appendingTestParameters(data: data.html)
        _=await tab.setUrl(pageUrl, source: .link)?.result

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
            .timeout(5, scheduler: DispatchQueue.main) { .init(TimeoutError() as NSError) }.first().promise().get()

        XCTAssertEqual(fileUrl, FileManager.default.temporaryDirectory.appendingPathComponent("helloWorld_\(suffix).txt"))
        XCTAssertEqual(try? Data(contentsOf: fileUrl), data.testData)
    }

    @MainActor
    func testWhenNavigationActionIsBlob_downloadStarts() async throws {
        let preferences = DownloadsPreferences.shared
        preferences.alwaysRequestDownloadLocation = false
        preferences.selectedDownloadLocation = FileManager.default.temporaryDirectory

        let tab = tabViewModel.tab
        // load empty page
        let pageUrl = URL.testsServer.appendingTestParameters(data: data.html)
        _=await tab.setUrl(pageUrl, source: .link)?.result

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
            .timeout(1, scheduler: DispatchQueue.main) { .init(TimeoutError() as NSError) }.first().promise().get()

        XCTAssertEqual(fileUrl, FileManager.default.temporaryDirectory.appendingPathComponent("blobdload_\(suffix).json"))
        XCTAssertEqual(try? Data(contentsOf: fileUrl), data.testData)
    }

}

@available(macOS 12.0, *)
private extension DownloadsIntegrationTests {
    func click(_ view: NSView) {
        let point = view.convert(view.bounds.center, to: nil)
        let mouseDown = NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0, windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        let mouseUp = NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [], timestamp: 0, windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!

        window.sendEvent(mouseDown)
        window.sendEvent(mouseUp)
    }
}

extension WebKitDownloadTask {

    var output: AnyPublisher<URL, FileDownloadError> {
        $state.tryCompactMap { state in
            switch state {
            case .initial, .downloading:
                return nil
            case .downloaded(let destinationFile):
                return destinationFile.url
            case .failed(_, _, resumeData: _, error: let error):
                throw error
            }
        }
        .mapError { $0 as! FileDownloadError } // swiftlint:disable:this force_cast
        .first()
        .eraseToAnyPublisher()
    }

}
