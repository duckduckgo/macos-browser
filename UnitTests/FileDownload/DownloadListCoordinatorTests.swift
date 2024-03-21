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

import Common
import Foundation
import UniformTypeIdentifiers
import XCTest

@testable import DuckDuckGo_Privacy_Browser

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

    override func setUp() {
        self.destURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        self.tempURL = fm.temporaryDirectory.appendingPathComponent(testFile).appendingPathExtension("duckload")
    }

    func setUpCoordinator() {
        coordinator = DownloadListCoordinator(store: store, downloadManager: downloadManager, clearItemsOlderThan: Date.daysAgo(2)) {
            return self.webView
        }
    }

    @MainActor
    func setUpCoordinatorAndAddDownload(isBurner: Bool = false) -> (WKDownloadMock, WebKitDownloadTask, UUID) {
        setUpCoordinator()
        let download = WKDownloadMock(url: .duckDuckGo)

        let fm = FileManager.default
        XCTAssertTrue(fm.createFile(atPath: destURL.path, contents: nil))
        let destFile = try! FilePresenter(url: destURL)
        XCTAssertTrue(fm.createFile(atPath: tempURL.path, contents: "test".utf8data))
        let tempFile = try! FilePresenter(url: tempURL)

        let task = WebKitDownloadTask(download: download, destination: .resume(destination: destFile, tempFile: tempFile), isBurner: isBurner)

        let e = expectation(description: "download added")
        var id: UUID!
        let c = coordinator.updates.sink { kind, item in
            if kind == .added {
                e.fulfill()
                id = item.identifier
            }
        }
        downloadManager.downloadAddedSubject.send(task)
        task.start(delegate: downloadManager)
        waitForExpectations(timeout: 1)
        c.cancel()

        return (download, task, id)
    }

    // MARK: - Tests

    @MainActor
    func testWhenCoordinatorInitializedThenDownloadItemsAreLoadedFromStore() {
        OSLog.enabledLoggingCategories = [OSLog.AppCategories.downloads.rawValue]

        let items: [DownloadListItem] = [.testItem, .yesterdaysItem, .olderItem, .testRemovedItem, .testFailedItem]
        let expectedItems: [DownloadListItem] = [.testItem, .yesterdaysItem, .testFailedItem]

        let e1 = expectation(description: "fetch called")
        store.fetchBlock = { completionHandler in
            e1.fulfill()
            let fm = FileManager()
            for item in items where item != .testRemovedItem {
                XCTAssertTrue(fm.createFile(atPath: item.destinationURL!.path, contents: nil))
                if let tempURL = item.tempURL {
                    XCTAssertTrue(fm.createFile(atPath: tempURL.path, contents: "test".utf8data))
                }
            }
            completionHandler(.success(items))
        }
        setUpCoordinator()
        waitForExpectations(timeout: 1)

        let resultItems = coordinator.downloads(sortedBy: \.modified, ascending: true)
        XCTAssertEqual(resultItems.map(\.identifier), expectedItems.map(\.identifier))
        XCTAssertEqual(resultItems.compactMap { $0.destinationBookmarkData }.count, 3)
    }

    @MainActor
    func testWhenInitialLoadingFailsThenDownloadItemsAreEmpty() {
        let e1 = expectation(description: "fetch called")
        store.fetchBlock = { completionHandler in
            e1.fulfill()
            completionHandler(.failure(TestError()))
        }
        setUpCoordinator()

        waitForExpectations(timeout: 0)

        XCTAssertEqual(coordinator.downloads(sortedBy: \.modified, ascending: true), [])
    }

    @MainActor
    func testWhenStoreItemsAreLoadedThenUpdatesArePublished() {
        var itemsLoaded: ((Result<[DownloadListItem], Error>) -> Void)!
        store.fetchBlock = { completionHandler in
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

    @MainActor
    func testWhenDownloadAddedThenDownloadItemIsPublished() {
        setUpCoordinator()

        let destURL = fm.temporaryDirectory.appendingPathComponent("test file.pdf")
        let tempURL = fm.temporaryDirectory.appendingPathComponent("test file.duckload")
        let task = WebKitDownloadTask(download: WKDownloadMock(url: .duckDuckGo), destination: .preset(destURL), isBurner: false)

        let e = expectation(description: "download added")
        let c = coordinator.updates.sink { [coordinator] (kind, item) in
            XCTAssertEqual(kind, .added)
            XCTAssertEqual(item.destinationURL, destURL)
            XCTAssertEqual(item.tempURL, tempURL)
            XCTAssertEqual(item.progress, task.progress)
            XCTAssertTrue(coordinator!.hasActiveDownloads)
            e.fulfill()
        }

        downloadManager.downloadAddedSubject.send(task)
        task.start(delegate: downloadManager)

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertTrue(coordinator.hasActiveDownloads)
    }

    @MainActor
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

    @MainActor
    func testWhenDownloadFromBurnerWindowFinishesThenDownloadItemRemoved() {
        let (download, task, _) = setUpCoordinatorAndAddDownload(isBurner: true)

        let taskRemoved = expectation(description: "Task removed")
        let c = coordinator.updates.sink { (kind, item) in
            XCTAssertTrue(item.isBurner)

            if case .removed = kind {
                taskRemoved.fulfill()
            }
        }

        task.downloadDidFinish(download.asWKDownload())

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertFalse(coordinator.hasActiveDownloads)
    }

    @MainActor
    func testWhenDownloadFailsThenDownloadItemUpdatedWithError() {
        let (download, task, _) = setUpCoordinatorAndAddDownload()

        let taskCompleted = expectation(description: "location updated")
        var isFulfilled = false
        let c = coordinator.updates.sink { (kind, item) in
            XCTAssertEqual(kind, .updated)
            if !isFulfilled {
                isFulfilled = true
                taskCompleted.fulfill()
            }
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

    @MainActor
    func testWhenPreloadedDownloadRestartedWithResumeDataThenResumeIsCalled() throws {
        var item: DownloadListItem = .testFailedItem
        item.tempURL = self.tempURL

        store.fetchBlock = { completionHandler in
            completionHandler(.success([item]))
        }
        setUpCoordinator()

        let resumeCalled = expectation(description: "resume called")
        webView.resumeDownloadBlock = { [testFile, tempURL] data in
            resumeCalled.fulfill()
            let resumeData = try? data.map(DownloadResumeData.init(resumeData:))
            XCTAssertEqual(resumeData?.localPath, tempURL!.path)
            XCTAssertEqual(resumeData?.tempFileName, testFile.dropping(suffix: "." + testFile.pathExtension).appendingPathExtension("duckload"))
            return WKDownloadMock(url: .duckDuckGo)
        }
        webView.startDownloadBlock = { _ in
            XCTFail("unexpected start call")
            return nil
        }

        let downloadAdded = expectation(description: "download addeed")
        downloadManager.addDownloadBlock = { [unowned self] download, _, destination in
            downloadAdded.fulfill()
            let task = WebKitDownloadTask(download: download, destination: destination, isBurner: false)
            self.downloadManager.downloadAddedSubject.send(task)
            task.start(delegate: self.downloadManager)
            if case .resume(destination: let dest, tempFile: let temp) = destination {
                XCTAssertEqual(dest.url, destURL)
                XCTAssertEqual(temp.url, tempURL)
            } else {
                XCTFail("unexpected destination: \(destination)")
            }
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

    @MainActor
    func testWhenAddedDownloadRestartedWithResumeDataThenResumeIsCalled() throws {
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
            return WKDownloadMock(url: .duckDuckGo)
        }
        webView.startDownloadBlock = { _ in
            XCTFail("unexpected start call")
            return nil
        }

        let downloadAdded = expectation(description: "download addeed")
        downloadManager.addDownloadBlock = { [unowned self] download, _, destination in
            downloadAdded.fulfill()
            let task = WebKitDownloadTask(download: download, destination: destination, isBurner: false)
            self.downloadManager.downloadAddedSubject.send(task)
            task.start(delegate: self.downloadManager)
            if case .resume(destination: let dest, tempFile: let temp) = destination {
                XCTAssertEqual(dest.url, destURL)
                XCTAssertEqual(temp.url, tempURL)
            } else {
                XCTFail("unexpected destination: \(destination)")
            }
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

    @MainActor
    func testWhenDownloadRestartedWithoutResumeDataThenDownloadIsStarted() throws {
        var item: DownloadListItem = .testFailedItem
        item.tempURL = self.tempURL
        item.error = .failedToCompleteDownloadTask(underlyingError: TestError(), resumeData: nil, isRetryable: false)
        store.fetchBlock = { completionHandler in
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
            XCTAssertEqual(request?.url, item.downloadURL)
            return WKDownloadMock(url: .duckDuckGo)
        }

        let downloadAdded = expectation(description: "download addeed")
        downloadManager.addDownloadBlock = { [unowned self] download, _, destination in
            downloadAdded.fulfill()
            let task = WebKitDownloadTask(download: download, destination: destination, isBurner: false)
            self.downloadManager.downloadAddedSubject.send(task)
            task.start(delegate: self.downloadManager)
            if case .resume(destination: let dest, tempFile: let temp) = destination {
                XCTAssertEqual(dest.url, destURL)
                XCTAssertEqual(temp.url, tempURL)
            } else {
                XCTFail("unexpected destination: \(destination)")
            }
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

    @MainActor
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

    @MainActor
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

    @MainActor
    func testWhenDownloadCancelledThenTaskIsCancelled() {
        let (download, _, id) = setUpCoordinatorAndAddDownload()
        let e = expectation(description: "cancelled")
        download.cancelBlock = {
            e.fulfill()
        }
        coordinator.cancel(downloadWithIdentifier: id)
        waitForExpectations(timeout: 1)
    }

    @MainActor
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
    static let resumeData: Data = {
        let dict = [
            "NSURLSessionResumeInfoLocalPath": FileManager.default.temporaryDirectory.appendingPathComponent("downloaded file.duckload"),
            "NSURLSessionResumeInfoTempFileName": "downloaded file.pdf"
        ]
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.encode(dict, forKey: "NSKeyedArchiveRootObjectKey")
        archiver.finishEncoding()
        return archiver.encodedData
    }()
}
private extension DownloadListItem {

    static let testItem = DownloadListItem(identifier: UUID(),
                                           added: Date(),
                                           modified: Date(),
                                           downloadURL: URL(string: "https://duckduckgo.com/testdload")!,
                                           websiteURL: .duckDuckGo,
                                           fileName: "testItem.pdf",
                                           progress: nil,
                                           isBurner: false,
                                           destinationURL: FileManager.default.temporaryDirectory.appendingPathComponent("testItem.pdf"),
                                           destinationBookmarkData: nil,
                                           tempURL: nil,
                                           tempFileBookmarkData: nil,
                                           error: nil)

    static let yesterdaysItem = DownloadListItem(identifier: UUID(),
                                                 added: .daysAgo(30),
                                                 modified: .daysAgo(1),
                                                 downloadURL: .duckDuckGo,
                                                 websiteURL: .duckDuckGo,
                                                 fileName: "oldItem.pdf",
                                                 progress: nil,
                                                 isBurner: false,
                                                 destinationURL: FileManager.default.temporaryDirectory.appendingPathComponent("oldItem.pdf"),
                                                 destinationBookmarkData: nil,
                                                 tempURL: nil,
                                                 tempFileBookmarkData: nil,
                                                 error: nil)

    static let olderItem = DownloadListItem(identifier: UUID(),
                                            added: .daysAgo(30),
                                            modified: .daysAgo(3),
                                            downloadURL: URL(string: "https://testdownload.com")!,
                                            websiteURL: nil,
                                            fileName: "outdated_fileName",
                                            progress: nil,
                                            isBurner: false,
                                            destinationURL: FileManager.default.temporaryDirectory.appendingPathComponent("olderItem.pdf"),
                                            destinationBookmarkData: nil,
                                            tempURL: nil,
                                            tempFileBookmarkData: nil,
                                            error: nil)

    static let testRemovedItem = DownloadListItem(identifier: UUID(),
                                                  added: Date(),
                                                  modified: Date(),
                                                  downloadURL: URL(string: "https://duckduckgo.com/testdload")!,
                                                  websiteURL: .duckDuckGo,
                                                  fileName: "fileName",
                                                  progress: nil,
                                                  isBurner: false,
                                                  destinationURL: URL(fileURLWithPath: "/test/path"),
                                                  destinationBookmarkData: nil,
                                                  tempURL: URL(fileURLWithPath: "/temp/file/path"),
                                                  tempFileBookmarkData: nil,
                                                  error: nil)

    static let testFailedItem = DownloadListItem(identifier: UUID(),
                                                 added: Date(),
                                                 modified: Date(),
                                                 downloadURL: URL(string: "https://duckduckgo.com/testdload")!,
                                                 websiteURL: .duckDuckGo,
                                                 fileName: "testFailedItem.pdf",
                                                 progress: nil,
                                                 isBurner: false,
                                                 destinationURL: FileManager.default.temporaryDirectory.appendingPathComponent("testFailedItem.pdf"),
                                                 destinationBookmarkData: nil,
                                                 tempURL: FileManager.default.temporaryDirectory.appendingPathComponent("testFailedItem.duckload"),
                                                 tempFileBookmarkData: nil,
                                                 error: .failedToCompleteDownloadTask(underlyingError: TestError(), resumeData: .resumeData, isRetryable: false))

}
