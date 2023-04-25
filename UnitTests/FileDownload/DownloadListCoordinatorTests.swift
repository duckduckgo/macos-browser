//
//  DownloadListCoordinatorTests.swift
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

@available(macOS 11.3, *)
@MainActor
final class DownloadListCoordinatorTests: XCTestCase {
    let store = DownloadListStoreMock()
    let downloadManager = FileDownloadManagerMock()
    var coordinator: DownloadListCoordinator!

    let fm = FileManager.default
    let testFile = "downloaded file.pdf"
    var destURL: URL!
    var tempURL: URL!

    var chooseDestinationBlock: ((String?, URL?, [UTType], @escaping (URL?, UTType?) -> Void) -> Void)?

    lazy var webView = DownloadsWebViewMock()

    func clearTemp() {
        let tempDir = fm.temporaryDirectory
        for file in (try? fm.contentsOfDirectory(atPath: tempDir.path)) ?? [] where file.hasPrefix(testFile) {
            try? fm.removeItem(at: tempDir.appendingPathComponent(file))
        }
    }

    override func setUp() {
        clearTemp()

        self.destURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        self.tempURL = fm.temporaryDirectory.appendingPathComponent(testFile).appendingPathExtension("duckload")
        fm.createFile(atPath: tempURL.path, contents: "test".data(using: .utf8)!, attributes: nil)
    }

    override func tearDown() {
        clearTemp()
    }

    func setUpCoordinator() {
        coordinator = DownloadListCoordinator(store: store, downloadManager: downloadManager, clearItemsOlderThan: Date.daysAgo(2)) {
            return self.webView
        }
    }

    func setUpCoordinatorAndAddDownload() -> (WKDownloadMock, WebKitDownloadTask, UUID) {
        setUpCoordinator()
        let download = WKDownloadMock()
        let task = WebKitDownloadTask(download: download, promptForLocation: false, destinationURL: destURL, tempURL: tempURL, isBurner: false)

        let e = expectation(description: "download added")
        var id: UUID!
        let c = coordinator.updates.sink { _, item in
            e.fulfill()
            id = item.identifier
        }
        downloadManager.downloadAddedSubject.send(task)
        waitForExpectations(timeout: 1)
        c.cancel()

        return (download, task, id)
    }

    // MARK: - Tests

    func testWhenCoordinatorInitializedThenClearItemsBeforeIsCalled() {
        let clearDate: Date = Date.daysAgo(2)
        let e = expectation(description: "clear older than date called")
        store.fetchBlock = { date, _ in
            e.fulfill()
            XCTAssertEqual(Int(clearDate.timeIntervalSinceReferenceDate), Int(date.timeIntervalSinceReferenceDate))
        }
        setUpCoordinator()

        waitForExpectations(timeout: 0)
    }

    func testWhenCoordinatorInitializedThenDownloadItemsAreLoadedFromStore() {
        store.fetchBlock = { _, completionHandler in
            completionHandler(.success([.testItem, .olderItem]))
        }
        setUpCoordinator()

        XCTAssertEqual(coordinator.downloads(sortedBy: \.modified, ascending: true), [.olderItem, .testItem])
    }

    func testWhenInitialLoadingFailsThenDownloadItemsAreEmpty() {
        store.fetchBlock = { _, completionHandler in
            completionHandler(.failure(TestError()))
        }
        setUpCoordinator()

        XCTAssertEqual(coordinator.downloads(sortedBy: \.modified, ascending: true), [])

    }

    func testWhenStoreItemsAreLoadedThenUpdatesArePublished() {
        var itemsLoaded: ((Result<[DownloadListItem], Error>) -> Void)!
        store.fetchBlock = { _, completionHandler in
            itemsLoaded = completionHandler
        }

        setUpCoordinator()
        XCTAssertEqual(coordinator.downloads(sortedBy: \.modified, ascending: true), [])

        let e1 = expectation(description: "item 1 added")
        let e2 = expectation(description: "item 2 added")
        let c = coordinator.updates.sink { (kind, item) in
            XCTAssertEqual(kind, .added)
            switch item {
            case .testItem:
                e1.fulfill()
            case .olderItem:
                e2.fulfill()
            default:
                XCTFail("unexpected item")
            }
        }

        itemsLoaded(.success([.testItem, .olderItem]))
        withExtendedLifetime(c) {
            waitForExpectations(timeout: 0)
        }
    }

    func testWhenDownloadAddedThenDownloadItemIsPublished() {
        setUpCoordinator()

        let task = WebKitDownloadTask(download: WKDownloadMock(), promptForLocation: false, destinationURL: destURL, tempURL: tempURL, isBurner: false)

        let e = expectation(description: "download added")
        let c = coordinator.updates.sink { [coordinator] (kind, item) in
            XCTAssertEqual(kind, .added)
            XCTAssertEqual(item.destinationURL, self.destURL)
            XCTAssertEqual(item.tempURL, self.tempURL)
            XCTAssertEqual(item.progress, task.progress)
            XCTAssertTrue(coordinator!.hasActiveDownloads)
            e.fulfill()
        }

        downloadManager.downloadAddedSubject.send(task)

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertTrue(coordinator.hasActiveDownloads)
    }

    func testWhenDownloadFinishesThenDownloadItemUpdated() {
        let (download, task, _) = setUpCoordinatorAndAddDownload()

        let locationUpdated = expectation(description: "location updated")
        let taskCompleted = expectation(description: "location updated")
        let c = coordinator.updates.sink { (kind, item) in
            XCTAssertEqual(kind, .updated)
            if item.progress != nil {
                locationUpdated.fulfill()
            } else {
                taskCompleted.fulfill()

                XCTAssertEqual(item.destinationURL, self.destURL)
                XCTAssertNil(item.tempURL)
                XCTAssertNil(item.progress)
            }
        }

        task.downloadDidFinish(download.asWKDownload())

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertFalse(coordinator.hasActiveDownloads)
    }

    func testWhenDownloadFailsThenDownloadItemUpdatedWithError() {
        let (download, task, _) = setUpCoordinatorAndAddDownload()

        let taskCompleted = expectation(description: "location updated")
        let c = coordinator.updates.sink { (kind, item) in
            XCTAssertEqual(kind, .updated)
            taskCompleted.fulfill()

            XCTAssertEqual(item.destinationURL, self.destURL)
            XCTAssertEqual(item.tempURL, self.tempURL)
            XCTAssertNil(item.progress)
            XCTAssertEqual(item.error, FileDownloadError.failedToCompleteDownloadTask(underlyingError: TestError(), resumeData: .resumeData, isRetryable: true))
            XCTAssertEqual(item.error?.resumeData, .resumeData)
        }

        task.download(download.asWKDownload(), didFailWithError: TestError(), resumeData: .resumeData)

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertFalse(coordinator.hasActiveDownloads)
    }

    func testWhenPreloadedDownloadRestartedWithResumeDataThenResumeIsCalled() {
        var item: DownloadListItem = .testFailedItem
        item.tempURL = self.tempURL
        store.fetchBlock = { _, completionHandler in
            completionHandler(.success([item]))
        }
        setUpCoordinator()

        let resumeCalled = expectation(description: "resume called")
        webView.resumeDownloadBlock = { data in
            resumeCalled.fulfill()
            XCTAssertEqual(data, .resumeData)
            return WKDownloadMock()
        }
        webView.startDownloadBlock = { _ in
            XCTFail("unexpected start call")
            return nil
        }

        let downloadAdded = expectation(description: "download addeed")
        downloadManager.addDownloadBlock = { [unowned self] download, _, location in
            downloadAdded.fulfill()
            let task = WebKitDownloadTask(download: download,
                                          promptForLocation: location == .prompt ? true : false,
                                          destinationURL: location.destinationURL,
                                          tempURL: location.tempURL,
                                          isBurner: false)
            self.downloadManager.downloadAddedSubject.send(task)
            XCTAssertEqual(location, .preset(destinationURL: item.destinationURL!, tempURL: item.tempURL))
            return task
        }

        let itemUpdated = expectation(description: "item updated")
        let c = coordinator.updates.sink { (kind, item) in
            XCTAssertEqual(kind, .updated)
            itemUpdated.fulfill()

            XCTAssertEqual(item.destinationURL, item.destinationURL)
            XCTAssertEqual(item.tempURL, item.tempURL)
            XCTAssertNotNil(item.progress)
            XCTAssertNil(item.error)
        }

        coordinator.restart(downloadWithIdentifier: DownloadListItem.testFailedItem.identifier)

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertEqual(coordinator.downloads(sortedBy: \.modified, ascending: true).count, 1)
    }

    func testWhenAddedDownloadRestartedWithResumeDataThenResumeIsCalled() {
        let (download, task, id) = setUpCoordinatorAndAddDownload()
        let taskFailed = expectation(description: "task failed")
        let c1 = coordinator.updates.sink { _, _ in
            taskFailed.fulfill()
        }
        task.download(download.asWKDownload(), didFailWithError: TestError(), resumeData: .resumeData)
        waitForExpectations(timeout: 1)
        c1.cancel()

        let resumeCalled = expectation(description: "resume called")
        webView.resumeDownloadBlock = { data in
            resumeCalled.fulfill()
            XCTAssertEqual(data, .resumeData)
            return WKDownloadMock()
        }
        webView.startDownloadBlock = { _ in
            XCTFail("unexpected start call")
            return nil
        }

        let downloadAdded = expectation(description: "download addeed")
        downloadManager.addDownloadBlock = { [unowned self] download, _, location in
            downloadAdded.fulfill()
            let task = WebKitDownloadTask(download: download,
                                          promptForLocation: location == .prompt ? true : false,
                                          destinationURL: location.destinationURL,
                                          tempURL: location.tempURL,
                                          isBurner: false)
            self.downloadManager.downloadAddedSubject.send(task)
            XCTAssertEqual(location, .preset(destinationURL: self.destURL, tempURL: self.tempURL))
            return task
        }

        let itemUpdated = expectation(description: "item updated")
        let c = coordinator.updates.sink { (kind, item) in
            XCTAssertEqual(kind, .updated)
            itemUpdated.fulfill()

            XCTAssertEqual(item.destinationURL, item.destinationURL)
            XCTAssertEqual(item.tempURL, item.tempURL)
            XCTAssertNotNil(item.progress)
            XCTAssertNil(item.error)
        }

        coordinator.restart(downloadWithIdentifier: id)

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertEqual(coordinator.downloads(sortedBy: \.modified, ascending: true).count, 1)
    }

    func testWhenDownloadRestartedWithoutResumeDataThenDownloadIsStarted() {
        var item: DownloadListItem = .testFailedItem
        item.tempURL = self.tempURL
        item.error = .failedToCompleteDownloadTask(underlyingError: TestError(), resumeData: nil, isRetryable: false)
        store.fetchBlock = { _, completionHandler in
            completionHandler(.success([item]))
        }
        setUpCoordinator()

        let startCalled = expectation(description: "start called")
        webView.resumeDownloadBlock = { _ in
            XCTFail("unexpected resume call")
            return nil
        }
        webView.startDownloadBlock = { request in
            startCalled.fulfill()
            XCTAssertEqual(request?.url, item.url)
            return WKDownloadMock()
        }

        let downloadAdded = expectation(description: "download addeed")
        downloadManager.addDownloadBlock = { [unowned self] download, _, location in
            downloadAdded.fulfill()
            let task = WebKitDownloadTask(download: download,
                                          promptForLocation: location == .prompt ? true : false,
                                          destinationURL: location.destinationURL,
                                          tempURL: location.tempURL,
                                          isBurner: false)
            self.downloadManager.downloadAddedSubject.send(task)
            XCTAssertEqual(location, .preset(destinationURL: item.destinationURL!, tempURL: item.tempURL))
            return task
        }

        let itemUpdated = expectation(description: "item updated")
        let c = coordinator.updates.sink { (kind, item) in
            XCTAssertEqual(kind, .updated)
            itemUpdated.fulfill()

            XCTAssertEqual(item.destinationURL, item.destinationURL)
            XCTAssertEqual(item.tempURL, item.tempURL)
            XCTAssertNotNil(item.progress)
            XCTAssertNil(item.error)
        }

        coordinator.restart(downloadWithIdentifier: DownloadListItem.testFailedItem.identifier)

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertEqual(coordinator.downloads(sortedBy: \.modified, ascending: true).count, 1)
    }

    func testWhenDownloadRemovedThenUpdateIsPublished() {
        let (download, _, id) = setUpCoordinatorAndAddDownload()

        let itemRemoved = expectation(description: "item removed")
        let c = coordinator.updates.sink { (kind, item) in
            XCTAssertEqual(kind, .removed)
            itemRemoved.fulfill()

            XCTAssertEqual(item.identifier, id)
        }
        let cancelCalled = expectation(description: "download cancelled")
        download.cancelBlock = {
            cancelCalled.fulfill()
        }

        coordinator.remove(downloadWithIdentifier: id)
        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenInactiveDownloadsClearedThenOnlyInactiveDownloadsRemoved() {
        let (download1, task1, _) = setUpCoordinatorAndAddDownload()
        let (download2, task2, _) = setUpCoordinatorAndAddDownload()
        let (download3, task3, _) = setUpCoordinatorAndAddDownload()

        task2.download(download2.asWKDownload(), didFailWithError: TestError(), resumeData: nil)
        task3.downloadDidFinish(download3.asWKDownload())

        let clearCalled = expectation(description: "clear called")
        store.clearBlock = { date, _ in
            clearCalled.fulfill()
            XCTAssertEqual(date, .distantFuture)
        }

        coordinator.cleanupInactiveDownloads()

        waitForExpectations(timeout: 1)
        XCTAssertTrue(coordinator.hasActiveDownloads)
        XCTAssertEqual(coordinator.downloads(sortedBy: \.modified, ascending: true).count, 1)

        task1.download(download1.asWKDownload(), didFailWithError: TestError(), resumeData: nil)
    }

    func testWhenDownloadCancelledThenTaskIsCancelled() {
        let (download, _, id) = setUpCoordinatorAndAddDownload()
        let e = expectation(description: "cancelled")
        download.cancelBlock = {
            e.fulfill()
        }
        coordinator.cancel(downloadWithIdentifier: id)
        waitForExpectations(timeout: 1)
    }

    func testSync() {
        let e = expectation(description: "sync called")
        store.syncBlock = {
            e.fulfill()
        }
        setUpCoordinator()
        coordinator.sync()
        waitForExpectations(timeout: 0)
    }

}

private struct TestError: Error, Equatable {}
private extension Data {
    static let resumeData = "resumeData".data(using: .utf8)!
}
private extension DownloadListItem {

    static let testFailedItem = DownloadListItem(identifier: UUID(),
                                                 added: Date(),
                                                 modified: Date(),
                                                 url: URL(string: "https://duckduckgo.com/testdload")!,
                                                 websiteURL: URL(string: "https://duckduckgo.com"),
                                                 progress: nil,
                                                 isBurner: false,
                                                 fileType: .pdf,
                                                 destinationURL: URL(fileURLWithPath: "/test/file/path"),
                                                 tempURL: URL(fileURLWithPath: "/temp/file/path"),
                                                 error: .failedToCompleteDownloadTask(underlyingError: TestError(), resumeData: .resumeData, isRetryable: false))

}
