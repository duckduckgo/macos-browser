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
    let fm = FileManager.default
    let testFile = "downloaded file"

    var chooseDestination: ((String?, URL?, [UTType], (URL?, UTType?) -> Void) -> Void)?
    var fileIconFlyAnimationOriginalRect: ((WebKitDownloadTask) -> NSRect?)?

    override func setUp() {
        defaults = UserDefaults(suiteName: testGroupName)!
        defaults.removePersistentDomain(forName: testGroupName)
        var prefs = DownloadPreferences(userDefaults: defaults)
        prefs.alwaysRequestDownloadLocation = false
        self.workspace = TestWorkspace()
        self.dm = FileDownloadManager(workspace: workspace, preferences: DownloadPreferences(userDefaults: defaults))
        let tempDir = fm.temporaryDirectory
        for file in (try? fm.contentsOfDirectory(atPath: tempDir.path)) ?? [] where file.hasPrefix(testFile) {
            try? fm.removeItem(at: tempDir.appendingPathComponent(file))
        }
    }

    override func tearDown() {
        FileManager.restoreUrlsForIn()
        self.chooseDestination = nil
        self.fileIconFlyAnimationOriginalRect = nil
    }

    func testWhenDownloadIsAddedThenItsPublished() {
        let e1 = expectation(description: "empty downloads populated")
        let e2 = expectation(description: "FileDownloadTask populated")
        let cancellable = dm.$downloads.sink { downloads in
            if downloads.isEmpty {
                e1.fulfill()
            } else if downloads.count == 1 {
                e2.fulfill()
            }
        }

        let download = WKDownloadMock()
        dm.add(download, delegate: nil, promptForLocation: false, postflight: .none)

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

        let download = WKDownloadMock()
        dm.add(download, delegate: nil, promptForLocation: false, postflight: .none)

        struct TestError: Error {}
        download.downloadDelegate?.download?(download, didFailWithError: TestError(), resumeData: nil)

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

        let download = WKDownloadMock()
        dm.add(download, delegate: nil, promptForLocation: false, postflight: .none)

        download.downloadDelegate?.downloadDidFinish?(download)

        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 0.3)
        }
        XCTAssertTrue(dm.downloads.isEmpty)
    }

    func testWhenRequiredByDownloadRequestThenDownloadLocationChooserIsCalled() {
        var prefs = DownloadPreferences(userDefaults: defaults)
        let downloadsURL = fm.temporaryDirectory
        prefs.selectedDownloadLocation = downloadsURL

        let e1 = expectation(description: "chooseDestinationCallback called")
        self.chooseDestination = { suggestedFilename, directoryURL, fileTypes, callback in
            dispatchPrecondition(condition: .onQueue(.main))
            XCTAssertEqual(suggestedFilename, "suggested.filename")
            XCTAssertEqual(directoryURL, downloadsURL)
            XCTAssertEqual(fileTypes, [.pdf])
            e1.fulfill()

            callback(nil, nil)
        }

        let download = WKDownloadMock()
        dm.add(download, delegate: self, promptForLocation: true, postflight: .none)

        let url = URL(string: "https://duckduckgo.com/somefile.html")!
        let response = URLResponse(url: url, mimeType: UTType.pdf.mimeType, expectedContentLength: 1, textEncodingName: "utf-8")
        let e2 = expectation(description: "WKDownload callback called")
        download.downloadDelegate?.download(download,
                                            decideDestinationUsing: response,
                                            suggestedFilename: "suggested.filename") { url in
            XCTAssertNil(url)
            e2.fulfill()
        }

        waitForExpectations(timeout: 0.3)
    }

    func testWhenRequiredByPreferencesThenDownloadLocationChooserIsCalled() {
        var prefs = DownloadPreferences(userDefaults: defaults)
        prefs.alwaysRequestDownloadLocation = true
        let downloadsURL = fm.temporaryDirectory
        prefs.selectedDownloadLocation = downloadsURL

        let localURL = downloadsURL.appendingPathComponent(testFile)
        let e1 = expectation(description: "chooseDestinationCallback called")
        self.chooseDestination = { suggestedFilename, directoryURL, fileTypes, callback in
            dispatchPrecondition(condition: .onQueue(.main))
            XCTAssertEqual(suggestedFilename, "suggested.filename")
            XCTAssertEqual(directoryURL, downloadsURL)
            XCTAssertEqual(fileTypes, [.html])
            e1.fulfill()

            callback(localURL, .html)
        }

        let download = WKDownloadMock()
        dm.add(download, delegate: self, promptForLocation: false, postflight: .none)

        let url = URL(string: "https://duckduckgo.com/somefile.html")!
        let response = URLResponse(url: url, mimeType: UTType.html.mimeType, expectedContentLength: 1, textEncodingName: "utf-8")
        let e2 = expectation(description: "WKDownload callback called")
        download.downloadDelegate?.download(download,
                                            decideDestinationUsing: response,
                                            suggestedFilename: "suggested.filename") { url in
            dispatchPrecondition(condition: .onQueue(.main))
            XCTAssertEqual(url, localURL.appendingPathExtension(WebKitDownloadTask.downloadExtension))
            e2.fulfill()
        }

        waitForExpectations(timeout: 0.3)
    }

    func testWhenChosenDownloadLocationExistsThenItsOverwritten() {
        let localURL = fm.temporaryDirectory.appendingPathComponent(testFile + ".jpg")
        fm.createFile(atPath: localURL.path, contents: nil, attributes: nil)
        XCTAssertTrue(fm.fileExists(atPath: localURL.path))

        let download = WKDownloadMock()
        dm.add(download, delegate: self, promptForLocation: true, postflight: .none)
        self.chooseDestination = { _, _, _, callback in
            callback(localURL, nil)
        }

        let e = expectation(description: "WKDownload called")
        download.downloadDelegate?.download(download, decideDestinationUsing: nil, suggestedFilename: "suggested.filename") { url in
            XCTAssertEqual(url, localURL.appendingPathExtension(WebKitDownloadTask.downloadExtension))
            e.fulfill()
        }

        waitForExpectations(timeout: 0.3)

        XCTAssertFalse(fm.fileExists(atPath: localURL.path))
    }

    func testWhenNotRequiredByPreferencesThenDefaultDownloadLocationIsChosen() {
        var prefs = DownloadPreferences(userDefaults: defaults)
        let downloadsURL = fm.temporaryDirectory
        prefs.selectedDownloadLocation = downloadsURL

        let download = WKDownloadMock()
        dm.add(download, delegate: self, promptForLocation: false, postflight: .none)
        self.chooseDestination = { _, _, _, _ in
            XCTFail("Unpected chooseDestination call")
        }

        let e = expectation(description: "WKDownload called")
        download.downloadDelegate?.download(download, decideDestinationUsing: nil, suggestedFilename: testFile) { [testFile] url in
            XCTAssertEqual(url, downloadsURL.appendingPathComponent(testFile).appendingPathExtension(WebKitDownloadTask.downloadExtension))
            e.fulfill()
        }

        waitForExpectations(timeout: 0.3)
    }

    func testWhenSuggestedFilenameIsEmptyThenItsUniquelyGenerated() {
        var prefs = DownloadPreferences(userDefaults: defaults)
        let downloadsURL = fm.temporaryDirectory
        prefs.selectedDownloadLocation = downloadsURL

        let download = WKDownloadMock()
        dm.add(download, delegate: self, promptForLocation: false, postflight: .none)
        self.chooseDestination = { _, _, _, _ in
            XCTFail("Unpected chooseDestination call")
        }

        let e = expectation(description: "WKDownload called")
        download.downloadDelegate?.download(download, decideDestinationUsing: nil, suggestedFilename: "") { url in
            XCTAssertEqual(url?.pathExtension, WebKitDownloadTask.downloadExtension)
            XCTAssertTrue(url?.lastPathComponent.count ?? 0 > WebKitDownloadTask.downloadExtension.count + 1)
            XCTAssertEqual(url?.deletingLastPathComponent(), downloadsURL)
            e.fulfill()
        }

        waitForExpectations(timeout: 0.3)
    }

    func testWhenDefaultDownloadsLocationIsReadOnlyThenDownloadFails() {
        var prefs = DownloadPreferences(userDefaults: defaults)
        prefs.selectedDownloadLocation = nil
        FileManager.swizzleUrlsForIn { _, _ in
            [URL(fileURLWithPath: "/")]
        }

        let download = WKDownloadMock()
        dm.add(download, delegate: self, promptForLocation: false, postflight: .none)

        let e1 = expectation(description: "FileDownloadTask populated")
        let e2 = expectation(description: "empty downloads populated")
        let cancellable = dm.$downloads.sink { downloads in
            if downloads.count == 1 {
                e1.fulfill()
            } else {
                e2.fulfill()
            }
        }

        let e3 = expectation(description: "WKDownload called")
        download.downloadDelegate?.download(download, decideDestinationUsing: nil, suggestedFilename: "") { url in
            XCTAssertNil(url)
            e3.fulfill()
        }

        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 0.3)
        }
    }

    func performPostflightTest(at url: URL, with postflight: FileDownloadManager.PostflightAction?, completion: @escaping (Selector, [URL]) -> Void) {
        let download = WKDownloadMock()
        let task = dm.add(download, delegate: self, promptForLocation: true, postflight: postflight)
        chooseDestination = { _, _, _, callback in
            callback(url, nil)
        }
        self.workspace.callback = { sel, urls in
            completion(sel, urls)
        }

        download.downloadDelegate?.download(download, decideDestinationUsing: nil, suggestedFilename: "") { [fm] url in
            fm.createFile(atPath: url!.path, contents: nil, attributes: nil)
        }

        let e = expectation(description: "WKDownload completed")
        let cancellable = task.output.sink { completion in
            if case .failure(let error) = completion {
                XCTFail("download failed with \(error)")
            }
            e.fulfill()
        } receiveValue: { dest in
            XCTAssertEqual(dest, url)
        }

        download.downloadDelegate?.downloadDidFinish?(download)

        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 0.3)
        }
    }

    func testWhenNoPostflightThenNoWorkspaceCalls() {
        let localURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        performPostflightTest(at: localURL, with: .none) { _, _ in
            XCTFail("Unexpected workspace call")
        }
    }

    func testWhenPostflightIsOpenThenFileIsOpened() {
        let localURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        let e = expectation(description: "Open File postflight called")
        performPostflightTest(at: localURL, with: .open) { (sel, urls) in
            XCTAssertEqual(sel, #selector(NSWorkspace.open(_:)))
            XCTAssertEqual(urls, [localURL])
            e.fulfill()
        }
    }

    func testWhenPostflightIsRevealThenFileIsRevealed() {
        let localURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        let e = expectation(description: "Open File postflight called")
        performPostflightTest(at: localURL, with: .reveal) { (sel, urls) in
            XCTAssertEqual(sel, #selector(NSWorkspace.activateFileViewerSelecting(_:)))
            XCTAssertEqual(urls, [localURL])
            e.fulfill()
        }
    }

}
// swiftlint:enable type_body_length

extension FileDownloadManagerTests: FileDownloadManagerDelegate {
    func chooseDestination(suggestedFilename: String?, directoryURL: URL?, fileTypes: [UTType], callback: @escaping (URL?, UTType?) -> Void) {
        self.chooseDestination?(suggestedFilename, directoryURL, fileTypes, callback)
    }

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

    @objc
    func swizzled_urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        guard let urlsForIn = Self.urlsForIn else { return self.urls(for: directory, in: domainMask) }

        return urlsForIn(directory, domainMask)
    }
}
