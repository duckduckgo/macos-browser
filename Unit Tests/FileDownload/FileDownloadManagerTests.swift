//
//  FileDownloadManagerTests.swift
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

// swiftlint:disable type_body_length
final class FileDownloadManagerTests: XCTestCase {
    private let testGroupName = "test"
    var defaults: UserDefaults!
    var workspace: TestWorkspace!
    var dm: FileDownloadManager!

    override func setUp() {
        defaults = UserDefaults(suiteName: testGroupName)!
        defaults.removePersistentDomain(forName: testGroupName)
        var prefs = DownloadPreferences(userDefaults: defaults)
        prefs.alwaysRequestDownloadLocation = false
        self.workspace = TestWorkspace()
        self.dm = FileDownloadManager(workspace: workspace, preferences: DownloadPreferences(userDefaults: defaults))
    }

    override func tearDown() {
        FileManager.restoreUrlsForIn()
    }

    func testWhenDownloadIsAddedThenItsStarted() {
        weak var task: FileDownloadTaskMock!
        let e = expectation(description: "FileDownloadTask instantiated")
        let download = FileDownloadRequestMock.download(nil, prompt: false) { download in
            e.fulfill()
            let downloadTask = FileDownloadTaskMock(download: download)
            task = downloadTask
            return task
        }
        dm.startDownload(download, postflight: .none)

        waitForExpectations(timeout: 0.3)
        XCTAssertTrue(task.isStarted)
    }

    func testWhenDownloadIsAddedThenItsPublished() {
        let e1 = expectation(description: "empty downloads populated")
        let e2 = expectation(description: "FileDownloadTask populated")
        let cancellable = dm.$downloads.sink { downloads in
            if let task = downloads.first {
                XCTAssertTrue(task is FileDownloadTaskMock)
                e2.fulfill()
            } else {
                e1.fulfill()
            }
        }

        dm.startDownload(FileDownloadRequestMock.download(nil, prompt: false), postflight: .none)
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 0.3)
        }
    }

    func testTestWhenDownloadTaskIsNilThenDownloadIsNotAdded() {
        let e = expectation(description: "empty downloads populated")
        let cancellable = dm.$downloads.sink { _ in e.fulfill() }

        let download = FileDownloadRequestMock.download(nil, prompt: false) { _ in nil }
        dm.startDownload(download, postflight: .none)
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 0.3)
        }
    }

    func testWhenDownloadFailsInstantlyThenItsRemoved() {
        let e1 = expectation(description: "FileDownloadTask populated")
        let e2 = expectation(description: "empty downloads populated")
        let cancellable = dm.$downloads.dropFirst().sink { downloads in
            if downloads.first != nil {
                e1.fulfill()
            } else {
                e2.fulfill()
            }
        }

        let download = FileDownloadRequestMock.download(nil, prompt: false) { download in
            let task = FileDownloadTaskMock(download: download)
            task.onStarted = { task in
                task.finish(with: .failure(.restartResumeNotSupported))
            }
            return task
        }
        dm.startDownload(download, postflight: .none)

        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 0.3)
        }
        XCTAssertTrue(dm.downloads.isEmpty)
    }

    func testWhenDownloadFinishesInstantlyThenItsRemoved() {
        let e1 = expectation(description: "FileDownloadTask populated")
        let e2 = expectation(description: "empty downloads populated")
        let cancellable = dm.$downloads.dropFirst().sink { downloads in
            if downloads.first != nil {
                e1.fulfill()
            } else {
                e2.fulfill()
            }
        }

        let download = FileDownloadRequestMock.download(nil, prompt: false) { download in
            let task = FileDownloadTaskMock(download: download)
            task.onStarted = { task in
                task.finish(with: .success(URL(fileURLWithPath: "/")))
            }
            return task
        }
        dm.startDownload(download, postflight: .none)

        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 0.3)
        }
        XCTAssertTrue(dm.downloads.isEmpty)
    }

    func testWhenRequiredByDownloadRequestThenDownloadLocationChooserIsCalled() {
        let url = URL(string: "https://duckduckgo.com/somefile.html")!
        var prefs = DownloadPreferences(userDefaults: defaults)
        let downloadsURL = FileManager.default.temporaryDirectory
        prefs.selectedDownloadLocation = downloadsURL

        let localURL = URL(fileURLWithPath: "/test/path")
        let e1 = expectation(description: "localFileURLCompletionHandler called")
        let download = FileDownloadRequestMock.download(url, prompt: true) { download in
            let task = FileDownloadTaskMock(download: download)
            task.onStarted = { $0.queryDestinationURL() }
            task.onLocalFileURLChosen = { url, fileType in
                XCTAssertEqual(url, localURL)
                XCTAssertEqual(fileType, .pdf)
                e1.fulfill()
            }
            task.fileTypes = [.html, .jpeg]
            return task
        }

        let e2 = expectation(description: "chooseDestinationCallback called")
        dm.startDownload(download,
                         chooseDestinationCallback: { suggestedFilename, directoryURL, fileTypes, callback in
                            dispatchPrecondition(condition: .onQueue(.main))
                            XCTAssertEqual(suggestedFilename, "somefile")
                            XCTAssertEqual(directoryURL, downloadsURL)
                            XCTAssertEqual(fileTypes, [.html, .jpeg])
                            e2.fulfill()

                            callback(localURL, .pdf)
                         },
                         postflight: .none)

        waitForExpectations(timeout: 0.3)
    }

    func testWhenRequiredByPreferencesThenDownloadLocationChooserIsCalled() {
        let url = URL(string: "https://duckduckgo.com/somefile.html")!
        var prefs = DownloadPreferences(userDefaults: defaults)
        prefs.alwaysRequestDownloadLocation = true
        let downloadsURL = FileManager.default.temporaryDirectory
        prefs.selectedDownloadLocation = downloadsURL

        let localURL = URL(fileURLWithPath: "/test/path")
        let e1 = expectation(description: "localFileURLCompletionHandler called")
        let download = FileDownloadRequestMock.download(url, prompt: false) { download in
            let task = FileDownloadTaskMock(download: download)
            task.onStarted = { $0.queryDestinationURL() }
            task.onLocalFileURLChosen = { url, fileType in
                XCTAssertEqual(url, localURL)
                XCTAssertEqual(fileType, .pdf)
                e1.fulfill()
            }
            task.fileTypes = [.html, .jpeg]
            return task
        }

        let e2 = expectation(description: "chooseDestinationCallback called")
        dm.startDownload(download,
                         chooseDestinationCallback: { suggestedFilename, directoryURL, fileTypes, callback in
                            dispatchPrecondition(condition: .onQueue(.main))
                            XCTAssertEqual(suggestedFilename, "somefile")
                            XCTAssertEqual(directoryURL, downloadsURL)
                            XCTAssertEqual(fileTypes, [.html, .jpeg])
                            e2.fulfill()

                            callback(localURL, .pdf)
                         },
                         postflight: .none)

        waitForExpectations(timeout: 0.3)
    }

    func testWhenChosenDownloadLocationExistsThenItsOverwritten() {
        let localURL = FileManager.default.temporaryDirectory.appendingPathComponent(.uniqueFilename())
        FileManager.default.createFile(atPath: localURL.path, contents: nil, attributes: nil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: localURL.path))

        let download = FileDownloadRequestMock.download(nil, prompt: true) { download in
            let task = FileDownloadTaskMock(download: download)
            task.onStarted = { $0.queryDestinationURL() }
            return task
        }

        let e = expectation(description: "chooseDestinationCallback called")
        dm.startDownload(download,
                         chooseDestinationCallback: { _, _, _, callback in
                            e.fulfill()
                            callback(localURL, nil)
                         },
                         postflight: .none)

        waitForExpectations(timeout: 0.3)

        XCTAssertFalse(FileManager.default.fileExists(atPath: localURL.path))
    }

    func testWhenNotRequiredByPreferencesThenDefaultDownloadLocationIsChosen() {
        let url = URL(string: "https://duckduckgo.com/somefile.pdf")!
        var prefs = DownloadPreferences(userDefaults: defaults)
        let downloadsURL = FileManager.default.temporaryDirectory
        prefs.selectedDownloadLocation = downloadsURL

        let e = expectation(description: "localFileURLCompletionHandler called")
        let download = FileDownloadRequestMock.download(url, prompt: false) { download in
            let task = FileDownloadTaskMock(download: download)
            task.fileTypes = [.pdf]
            task.onStarted = { $0.queryDestinationURL() }
            task.onLocalFileURLChosen = { url, fileType in
                XCTAssertEqual(url, downloadsURL.appendingPathComponent("somefile.pdf"))
                XCTAssertEqual(fileType, .pdf)
                e.fulfill()
            }
            return task
        }

        dm.startDownload(download,
                         chooseDestinationCallback: { _, _, _, _ in
                            XCTFail("chooseDestinationCallback shouldn't be called")
                         },
                         postflight: .none)

        waitForExpectations(timeout: 0.3)
    }

    func testWhenSuggestedFilenameIsEmptyThenItsUniquelyGenerated() {
        var prefs = DownloadPreferences(userDefaults: defaults)
        let downloadsURL = FileManager.default.temporaryDirectory
        prefs.selectedDownloadLocation = downloadsURL

        let e1 = expectation(description: "localFileURLCompletionHandler1 called")
        var localURL: URL!
        let download1 = FileDownloadRequestMock.download(nil, prompt: false) { download in
            let task = FileDownloadTaskMock(download: download)
            task.filename = ""
            task.onStarted = { $0.queryDestinationURL() }
            task.onLocalFileURLChosen = { url, fileType in
                localURL = url
                XCTAssertEqual(url?.deletingLastPathComponent(), downloadsURL)
                XCTAssertNil(fileType)
                e1.fulfill()
            }
            return task
        }

        dm.startDownload(download1, postflight: .none)
        waitForExpectations(timeout: 0.3)

        FileManager.default.createFile(atPath: localURL.path, contents: nil, attributes: nil)
        let e2 = expectation(description: "localFileURLCompletionHandler2 called")
        let download2 = FileDownloadRequestMock.download(nil, prompt: false) { download in
            let task = FileDownloadTaskMock(download: download)
            task.filename = ""
            task.onStarted = { $0.queryDestinationURL() }
            task.onLocalFileURLChosen = { url, fileType in
                XCTAssertEqual(url?.deletingLastPathComponent(), downloadsURL)
                XCTAssertNotEqual(url, localURL)
                XCTAssertNil(fileType)
                e2.fulfill()
            }
            return task
        }

        dm.startDownload(download2, postflight: .none)
        waitForExpectations(timeout: 0.3)
    }

    func testWhenDefaultDownloadsLocationIsReadOnlyThenDownloadFails() {
        var prefs = DownloadPreferences(userDefaults: defaults)
        prefs.selectedDownloadLocation = nil
        FileManager.swizzleUrlsForIn { _, _ in
            [URL(fileURLWithPath: "/")]
        }

        let e = expectation(description: "localFileURLCompletionHandler called")
        let download = FileDownloadRequestMock.download(nil, prompt: false) { download in
            let task = FileDownloadTaskMock(download: download)
            task.onStarted = { $0.queryDestinationURL() }
            task.onLocalFileURLChosen = { url, fileType in
                XCTAssertNil(url)
                XCTAssertNil(fileType)
                e.fulfill()
            }
            return task
        }

        dm.startDownload(download, postflight: .none)
        waitForExpectations(timeout: 0.3)
    }

    func testWhenNoPostflightThenNoWorkspaceCalls() {
        let url = URL(string: "https://duckduckgo.com/somefile.pdf")!
        let localURL = URL(fileURLWithPath: "/test/download/path")

        let e = expectation(description: "Task finished")
        let download = FileDownloadRequestMock.download(url, prompt: false) { download in
            let task = FileDownloadTaskMock(download: download)
            task.fileTypes = [.pdf]
            task.onStarted = { $0.queryDestinationURL() }
            task.onLocalFileURLChosen = { [unowned task] _, _ in
                task.finish(with: .success(localURL))
                e.fulfill()
            }
            return task
        }

        self.workspace.callback = { _, _ in
            XCTFail("Unexpected workspace call")
        }

        dm.startDownload(download, postflight: .none)
        waitForExpectations(timeout: 0.3)
    }

    func testWhenPostflightIsOpenThenFileIsOpened() {
        let url = URL(string: "https://duckduckgo.com/somefile.pdf")!
        let localURL = URL(fileURLWithPath: "/test/download/path")

        let download = FileDownloadRequestMock.download(url, prompt: false) { download in
            let task = FileDownloadTaskMock(download: download)
            task.fileTypes = [.pdf]
            task.onStarted = { $0.queryDestinationURL() }
            task.onLocalFileURLChosen = { [unowned task] _, _ in
                task.finish(with: .success(localURL))
            }
            return task
        }

        let e = expectation(description: "Open File postflight called")
        self.workspace.callback = { sel, urls in
            XCTAssertEqual(sel, #selector(NSWorkspace.open(_:)))
            XCTAssertEqual(urls, [localURL])
            e.fulfill()
        }

        dm.startDownload(download, postflight: .open)
        waitForExpectations(timeout: 0.3)
    }

    func testWhenPostflightIsRevealThenFileIsRevealed() {
        let url = URL(string: "https://duckduckgo.com/somefile.pdf")!
        let localURL = URL(fileURLWithPath: "/test/download/path")

        let download = FileDownloadRequestMock.download(url, prompt: false) { download in
            let task = FileDownloadTaskMock(download: download)
            task.fileTypes = [.pdf]
            task.onStarted = { $0.queryDestinationURL() }
            task.onLocalFileURLChosen = { [unowned task] _, _ in
                task.finish(with: .success(localURL))
            }
            return task
        }

        let e = expectation(description: "Open File postflight called")
        self.workspace.callback = { sel, urls in
            XCTAssertEqual(sel, #selector(NSWorkspace.activateFileViewerSelecting(_:)))
            XCTAssertEqual(urls, [localURL])
            e.fulfill()
        }

        dm.startDownload(download, postflight: .reveal)
        waitForExpectations(timeout: 0.3)
    }

}
// swiftlint:enable type_body_length

final class TestWorkspace: NSWorkspace {
    var callback: ((Selector, [URL]) -> Void)?

    override func open(_ url: URL) -> Bool {
        callback?(#selector(NSWorkspace.open(_:)), [url])
        return true
    }

    override func activateFileViewerSelecting(_ fileURLs: [URL]) {
        callback?(#selector(NSWorkspace.activateFileViewerSelecting(_:)), fileURLs)
    }

}

private extension FileManager {
    private static var urlsForIn: ((SearchPathDirectory, SearchPathDomainMask) -> [URL])?
    private static let lock = NSLock()
    private static var isSwizzled = false
    private static let originalUrlsForIn = {
        class_getInstanceMethod(FileManager.self, #selector(FileManager.urls(for:in:)))!
    }()
    private static let swizzledUrlsForIn = {
        class_getInstanceMethod(FileManager.self, #selector(FileManager.swizzled_urls(for:in:)))!
    }()

    static func swizzleUrlsForIn(with urlsForIn: @escaping ((SearchPathDirectory, SearchPathDomainMask) -> [URL])) {
        lock.lock()
        defer { lock.unlock() }
        if !self.isSwizzled {
            self.isSwizzled = true
            method_exchangeImplementations(originalUrlsForIn, swizzledUrlsForIn)
        }
        self.urlsForIn = urlsForIn
    }

    static func restoreUrlsForIn() {
        lock.lock()
        defer { lock.unlock() }
        if self.isSwizzled {
            self.isSwizzled = false
            method_exchangeImplementations(originalUrlsForIn, swizzledUrlsForIn)
        }
        self.urlsForIn = nil
    }

    @objc
    func swizzled_urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        guard let urlsForIn = Self.urlsForIn else { return self.urls(for: directory, in: domainMask) }

        return urlsForIn(directory, domainMask)
    }
}
