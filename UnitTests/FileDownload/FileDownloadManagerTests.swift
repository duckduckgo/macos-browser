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
import UniformTypeIdentifiers
import XCTest

@testable import DuckDuckGo_Privacy_Browser

final class FileDownloadManagerTests: XCTestCase {

    private let testGroupName = "test"
    var defaults: UserDefaults!
    var workspace: TestWorkspace!
    var dm: FileDownloadManager!
    var preferences: DownloadsPreferences!
    let fm = FileManager.default
    let testFile = "downloaded file"

    var chooseDestination: (@MainActor (String?, [UTType], @MainActor (URL?, UTType?) -> Void) -> Void)?
    var fileIconFlyAnimationOriginalRect: ((WebKitDownloadTask) -> NSRect?)?

    let response = URLResponse(url: .duckDuckGo,
                               mimeType: "text/html",
                               expectedContentLength: 150,
                               textEncodingName: nil)

    override func setUp() {
        defaults = UserDefaults(suiteName: testGroupName)!
        defaults.removePersistentDomain(forName: testGroupName)
        preferences = DownloadsPreferences(persistor: DownloadsPreferencesPersistorMock())
        preferences.alwaysRequestDownloadLocation = false
        preferences.lastUsedCustomDownloadLocation = fm.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        self.workspace = TestWorkspace()
        self.dm = FileDownloadManager(preferences: preferences)
        let tempDir = fm.temporaryDirectory
        for file in (try? fm.contentsOfDirectory(atPath: tempDir.path)) ?? [] where file.hasPrefix(testFile) {
            try? fm.removeItem(at: tempDir.appendingPathComponent(file))
        }
    }

    override func tearDown() {
        FileManager.restoreUrlsForIn()
        self.chooseDestination = nil
        self.fileIconFlyAnimationOriginalRect = nil
        preferences.alwaysRequestDownloadLocation = false
    }

    @MainActor
    func testWhenDownloadIsAddedThenItsPublished() {
        let e = expectation(description: "empty downloads populated")
        let cancellable = dm.downloadsPublisher.sink { _ in
            e.fulfill()
        }

        let download = WKDownloadMock(url: .duckDuckGo)
        dm.add(download, fireWindowSession: nil, delegate: nil, destination: .auto)

        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 0.3)
        }
    }

    @MainActor
    func testWhenDownloadFailsInstantlyThenItsRemoved() {
        let e = expectation(description: "FileDownloadTask populated")
        let cancellable = dm.downloadsPublisher.sink { _ in
            e.fulfill()
        }

        let download = WKDownloadMock(url: .duckDuckGo)
        dm.add(download, fireWindowSession: nil, delegate: nil, destination: .auto)

        struct TestError: Error {}
        download.delegate?.download!(download.asWKDownload(), didFailWithError: TestError(), resumeData: nil)

        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 0.3)
        }
        XCTAssertTrue(dm.downloads.isEmpty)
    }

    @MainActor
    func testWhenDownloadFinishesInstantlyThenItsRemoved() async {
        let e = expectation(description: "FileDownloadTask populated")
        let cancellable = dm.downloadsPublisher.sink { _ in
            e.fulfill()
        }

        let download = WKDownloadMock(url: .duckDuckGo)
        let tempURL = fm.temporaryDirectory.appendingPathComponent("download")
        dm.add(download, fireWindowSession: nil, delegate: nil, destination: .preset(tempURL))
        let url = await download.delegate?.download(download.asWKDownload(), decideDestinationUsing: URLResponse(url: .duckDuckGo, mimeType: nil, expectedContentLength: 1, textEncodingName: nil), suggestedFilename: "sf")
        XCTAssertNotNil(url)
        XCTAssertTrue(fm.createFile(atPath: url?.path ?? "", contents: nil))

        download.delegate?.downloadDidFinish!(download.asWKDownload())
        let eDownloadRemoved = expectation(description: "FileDownloadTask removed")
        let t = Task {
            while !dm.downloads.isEmpty {
                try await Task.sleep(interval: 0.01)
            }
            eDownloadRemoved.fulfill()
        }

        await fulfillment(of: [e, eDownloadRemoved], timeout: 1)
        withExtendedLifetime(cancellable) {}
        t.cancel()
    }

    @MainActor
    func testWhenRequiredByDownloadRequestThenDownloadLocationChooserIsCalled() {
        let downloadsURL = fm.temporaryDirectory
        preferences.selectedDownloadLocation = downloadsURL
        let lastUsedCustomDownloadLocation = preferences.lastUsedCustomDownloadLocation

        let e1 = expectation(description: "chooseDestinationCallback called")
        self.chooseDestination = { suggestedFilename, fileTypes, callback in
            dispatchPrecondition(condition: .onQueue(.main))
            XCTAssertEqual(suggestedFilename, "suggested.filename")
            XCTAssertEqual(fileTypes, [UTType(filenameExtension: "filename")!, .pdf])
            e1.fulfill()

            callback(nil, nil)
        }

        let download = WKDownloadMock(url: .duckDuckGo)
        dm.add(download, fireWindowSession: nil, delegate: self, destination: .prompt)

        let url = URL(string: "https://duckduckgo.com/somefile.html")!
        let response = URLResponse(url: url, mimeType: UTType.pdf.preferredMIMEType, expectedContentLength: 1, textEncodingName: "utf-8")
        let e2 = expectation(description: "WKDownload callback called")
        download.delegate?.download(download.asWKDownload(),
                                    decideDestinationUsing: response,
                                    suggestedFilename: "suggested.filename") { url in
            XCTAssertNil(url)
            e2.fulfill()
        }

        waitForExpectations(timeout: 0.3)
        XCTAssertEqual(preferences.lastUsedCustomDownloadLocation, lastUsedCustomDownloadLocation, "lastUsedCustomDownloadLocation shouldn‘t change")
    }

    @MainActor
    func testWhenRequiredByPreferencesThenDownloadLocationChooserIsCalled() {
        preferences.alwaysRequestDownloadLocation = true
        let downloadsURL = fm.temporaryDirectory
        preferences.lastUsedCustomDownloadLocation = downloadsURL

        let localURL = downloadsURL.appendingPathComponent(testFile)
        let e1 = expectation(description: "chooseDestinationCallback called")
        self.chooseDestination = { suggestedFilename, fileTypes, callback in
            dispatchPrecondition(condition: .onQueue(.main))
            XCTAssertEqual(suggestedFilename, "suggested.filename")
            XCTAssertEqual(fileTypes, [UTType(filenameExtension: "filename")!, .html])
            e1.fulfill()

            callback(localURL, .html)
        }

        let download = WKDownloadMock(url: .duckDuckGo)
        dm.add(download, fireWindowSession: nil, delegate: self, destination: .auto)

        let url = URL(string: "https://duckduckgo.com/somefile.html")!
        let response = URLResponse(url: url, mimeType: UTType.html.preferredMIMEType, expectedContentLength: 1, textEncodingName: "utf-8")
        let e2 = expectation(description: "WKDownload callback called")
        download.delegate?.download(download.asWKDownload(),
                                    decideDestinationUsing: response,
                                    suggestedFilename: "suggested.filename") { url in
            dispatchPrecondition(condition: .onQueue(.main))
            e2.fulfill()
        }

        waitForExpectations(timeout: 0.3)
        XCTAssertEqual(preferences.lastUsedCustomDownloadLocation, downloadsURL, "lastUsedCustomDownloadLocation should be saved")
    }

    @MainActor
    func testWhenChosenDownloadLocationExistsThenItsOverwritten() {
        let localURL = fm.temporaryDirectory.appendingPathComponent(testFile + ".jpg")
        XCTAssertTrue(fm.createFile(atPath: localURL.path, contents: nil, attributes: nil))

        let download = WKDownloadMock(url: .duckDuckGo)
        dm.add(download, fireWindowSession: nil, delegate: self, destination: .prompt)
        self.chooseDestination = { _, _, callback in
            callback(localURL, nil)
        }

        let e = expectation(description: "WKDownload called")
        download.delegate?.download(download.asWKDownload(), decideDestinationUsing: response, suggestedFilename: "suggested.filename") { url in
            e.fulfill()
        }

        waitForExpectations(timeout: 0.3)

        XCTAssertFalse(fm.fileExists(atPath: localURL.path))
        XCTAssertEqual(preferences.lastUsedCustomDownloadLocation, localURL.deletingLastPathComponent(), "lastUsedCustomDownloadLocation should be saved")
    }

    @MainActor
    func testWhenDownloadingLocalFileThenLocationChooserIsCalled() {
        let downloadsURL = fm.temporaryDirectory
        preferences.selectedDownloadLocation = downloadsURL

        let download = WKDownloadMock(url: URL(fileURLWithPath: "/some/path"))

        let localURL = downloadsURL.appendingPathComponent(testFile)
        let e1 = expectation(description: "chooseDestinationCallback called")
        self.chooseDestination = { suggestedFilename, fileTypes, callback in
            dispatchPrecondition(condition: .onQueue(.main))
            e1.fulfill()

            callback(localURL, .html)
        }

        dm.add(download, fireWindowSession: nil, delegate: self, destination: .auto)

        let e2 = expectation(description: "WKDownload called")
        download.delegate?.download(download.asWKDownload(), decideDestinationUsing: response, suggestedFilename: testFile) { url in
            e2.fulfill()
        }

        waitForExpectations(timeout: 0.3)
        XCTAssertEqual(preferences.lastUsedCustomDownloadLocation, downloadsURL, "lastUsedCustomDownloadLocation should be saved")
    }

    @MainActor
    func testWhenNotRequiredByPreferencesThenDefaultDownloadLocationIsChosen() {
        let downloadsURL = fm.temporaryDirectory
        preferences.selectedDownloadLocation = downloadsURL

        let download = WKDownloadMock(url: .duckDuckGo)
        dm.add(download, fireWindowSession: nil, delegate: self, destination: .auto)
        self.chooseDestination = { _, _, _ in
            XCTFail("Unpected chooseDestination call")
        }

        let e = expectation(description: "WKDownload called")
        download.delegate?.download(download.asWKDownload(), decideDestinationUsing: response, suggestedFilename: testFile) { url in
            XCTAssertNotNil(url)
            e.fulfill()
        }

        waitForExpectations(timeout: 0.3)
    }

    @MainActor
    func testWhenSuggestedFilenameIsEmptyThenItsUniquelyGenerated() {
        let downloadsURL = fm.temporaryDirectory
        preferences.selectedDownloadLocation = downloadsURL

        let download = WKDownloadMock(url: .duckDuckGo)
        dm.add(download, fireWindowSession: nil, delegate: self, destination: .auto)
        self.chooseDestination = { _, _, _ in
            XCTFail("Unpected chooseDestination call")
        }

        let e = expectation(description: "WKDownload called")
        download.delegate?.download(download.asWKDownload(), decideDestinationUsing: response, suggestedFilename: "") { url in
            XCTAssertEqual(url?.lastPathComponent, "download.html")
            XCTAssertTrue(url?.lastPathComponent.count ?? 0 > WebKitDownloadTask.downloadExtension.count + 1)
            e.fulfill()
        }

        waitForExpectations(timeout: 0.3)
    }

    @MainActor
    func testWhenDefaultDownloadsLocationIsNotWritableThenDownloadLocationIsRequested() {
        preferences.selectedDownloadLocation = nil
        FileManager.swizzleUrlsForIn { _, _ in
            [URL(fileURLWithPath: "/")]
        }

        let download = WKDownloadMock(url: .duckDuckGo)
        dm.add(download, fireWindowSession: nil, delegate: self, destination: .auto)

        let e1 = expectation(description: "download location requested")
        self.chooseDestination = { suggestedFilename, fileTypes, callback in
            dispatchPrecondition(condition: .onQueue(.main))
            XCTAssertEqual(suggestedFilename, "suggested.filename")
            e1.fulfill()

            callback(nil, nil)
        }

        let e2 = expectation(description: "WKDownload called")
        download.delegate?.download(download.asWKDownload(), decideDestinationUsing: response, suggestedFilename: "suggested.filename") { url in
            XCTAssertNil(url)
            e2.fulfill()
        }

        waitForExpectations(timeout: 0.3)
    }

}

extension FileDownloadManagerTests: DownloadTaskDelegate {

    @MainActor
    func chooseDestination(suggestedFilename: String?, fileTypes: [UTType], callback: @escaping @MainActor (URL?, UTType?) -> Void) {
        self.chooseDestination?(suggestedFilename, fileTypes, callback)
    }

    @MainActor
    func fileIconFlyAnimationOriginalRect(for downloadTask: WebKitDownloadTask) -> NSRect? {
        self.fileIconFlyAnimationOriginalRect?(downloadTask)
    }
}

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

    @objc dynamic func swizzled_urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        guard let urlsForIn = Self.urlsForIn else { return self.urls(for: directory, in: domainMask) }

        return urlsForIn(directory, domainMask)
    }
}
