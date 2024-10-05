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

import Combine
import Common
import Foundation
import UniformTypeIdentifiers
import XCTest

@testable import DuckDuckGo_Privacy_Browser

final class DownloadListCoordinatorTests: XCTestCase {
    var store: DownloadListStoreMock!
    var downloadManager: FileDownloadManagerMock!
    var coordinator: DownloadListCoordinator!
    var webView: DownloadsWebViewMock!

    let fm = FileManager.default
    var testFile: String!
    var destURL: URL!
    var tempURL: URL!

    var chooseDestinationBlock: ((String?, URL?, [UTType], @escaping (URL?, UTType?) -> Void) -> Void)?

    override func setUp() {
        self.store = DownloadListStoreMock()
        self.downloadManager = FileDownloadManagerMock()
        self.webView = DownloadsWebViewMock()
        self.testFile = UUID().uuidString + ".pdf"
        self.destURL = fm.temporaryDirectory.appendingPathComponent(testFile)
        self.tempURL = fm.temporaryDirectory.appendingPathComponent(testFile).deletingPathExtension().appendingPathExtension("duckload")
    }

    func setUpCoordinator() {
        coordinator = DownloadListCoordinator(store: store, downloadManager: downloadManager, clearItemsOlderThan: Date.daysAgo(2)) {
            return self.webView
        }
    }

    @MainActor
    func setUpCoordinatorAndAddDownload(isBurner: Bool = false) -> (WKDownloadMock, WebKitDownloadTask, UUID) {
        setUpCoordinator()
        return addDownload(isBurner: isBurner)
    }

    @MainActor
    func addDownload(tempURL: URL? = nil, destURL: URL? = nil, isBurner: Bool = false) -> (WKDownloadMock, WebKitDownloadTask, UUID) {
        let download = WKDownloadMock(url: .duckDuckGo)
        let fm = FileManager.default
        let destURL = destURL ?? self.destURL!
        XCTAssertTrue(fm.createFile(atPath: destURL.path, contents: nil))
        let destFile = try! FilePresenter(url: destURL)
        let tempURL = tempURL ?? self.tempURL!
        XCTAssertTrue(fm.createFile(atPath: tempURL.path, contents: "test".utf8data))
        let tempFile = try! FilePresenter(url: tempURL)

        var fireWindowSession: FireWindowSessionRef?
        if isBurner {
            let mainViewController = MainViewController(tabCollectionViewModel: TabCollectionViewModel(tabCollection: TabCollection(tabs: []), burnerMode: .init(isBurner: true)), autofillPopoverPresenter: DefaultAutofillPopoverPresenter())
            let mainWindowController = MainWindowController(mainViewController: mainViewController, popUp: false, fireWindowSession: .init())
            fireWindowSession = FireWindowSessionRef(window: mainWindowController.window)
        }
        let task = WebKitDownloadTask(download: download, destination: .resume(destination: destFile, tempFile: tempFile), fireWindowSession: fireWindowSession)

        let e = expectation(description: "download added")
        var id: UUID!
        let c = coordinator.updates.sink { update in
            if case .added = update.kind {
                e.fulfill()
                id = update.item.identifier
            }
        }
        downloadManager.downloadAddedSubject.send(task)
        task.start(delegate: downloadManager)
        waitForExpectations(timeout: 3)
        c.cancel()

        return (download, task, id)
    }

    // MARK: - Tests

    @MainActor
    func testWhenCoordinatorInitializedThenDownloadItemsAreLoadedFromStore() {
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
        XCTAssertEqual(resultItems.compactMap { $0.destinationFileBookmarkData }.count, 3)
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

        let items: [DownloadListItem] = [.testItem, .yesterdaysItem, .olderItem, .testRemovedItem, .testFailedItem]
        var expectations = [UUID: XCTestExpectation]()

        for item in items where item != .testRemovedItem {
            XCTAssertTrue(fm.createFile(atPath: item.destinationURL!.path, contents: nil))
            if let tempURL = item.tempURL {
                XCTAssertTrue(fm.createFile(atPath: tempURL.path, contents: "test".utf8data))
            }
            if item != .olderItem {
                expectations[item.identifier] = expectation(description: "\(item.fileName) added")
            }
        }

        let c = coordinator.updates.sink { update in
            if case .added = update.kind {
                expectations[update.item.identifier]!.fulfill()
            } else if case .updated = update.kind {
            } else {
                XCTFail("unexpected \(update.kind) \(update.item.fileName)")
            }
        }

        itemsLoaded(.success(items))
        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
    }

    @MainActor
    func testWhenFileIsRenamed_nameChangeUpdateIsPublished() {

    }

    @MainActor
    func testWhenDownloadAddedThenDownloadItemIsPublished() async {
        setUpCoordinator()

        let destURL = fm.temporaryDirectory.appendingPathComponent("test file.pdf")
        let tempURL = fm.temporaryDirectory.appendingPathComponent("test file.duckload")
        let download = WKDownloadMock(url: .duckDuckGo)
        let task = WebKitDownloadTask(download: download, destination: .preset(destURL), fireWindowSession: nil)

        let e1 = expectation(description: "download added")
        let e2 = expectation(description: "download updated")
        let c = coordinator.updates.sink { [coordinator] update in
            switch update.kind {
            case .added:
                XCTAssertEqual(update.item.progress, task.progress)
                XCTAssertTrue(coordinator!.hasActiveDownloads(for: nil))
                e1.fulfill()
            case .updated:
                guard let tempUrlValue = update.item.tempURL else { return }
                XCTAssertEqual(update.item.destinationURL, destURL)
                XCTAssertEqual(tempUrlValue, tempURL)
                XCTAssertEqual(update.item.fileName, destURL.lastPathComponent)
                e2.fulfill()
            case .removed:
                XCTFail("unexpected .removed")
            }
        }

        downloadManager.downloadAddedSubject.send(task)
        task.start(delegate: downloadManager)
        let url = await task.download(download.asWKDownload(), decideDestinationUsing: URLResponse(url: download.originalRequest!.url!, mimeType: nil, expectedContentLength: 1, textEncodingName: nil), suggestedFilename: destURL.lastPathComponent)
        XCTAssertNotNil(url)
        XCTAssertTrue(FileManager().createFile(atPath: url?.path ?? "", contents: nil))

        await fulfillment(of: [e1, e2], timeout: 5.0)
        withExtendedLifetime(c) {}
        XCTAssertTrue(coordinator.hasActiveDownloads(for: nil))
    }

    @MainActor
    func testWhenDownloadFinishesThenDownloadItemUpdated() {
        let (download, task, _) = setUpCoordinatorAndAddDownload()

        let taskCompleted = expectation(description: "item updated")
        var c: AnyCancellable!
        c = coordinator.updates.sink { update in
            guard case .updated = update.kind, update.item.progress == nil else { return }

            taskCompleted.fulfill()

            XCTAssertEqual(update.item.destinationURL, self.destURL)
            XCTAssertNil(update.item.tempURL)
            XCTAssertNil(update.item.progress)
            c?.cancel()
        }

        task.downloadDidFinish(download.asWKDownload())

        waitForExpectations(timeout: 1)
        c = nil

        XCTAssertFalse(coordinator.hasActiveDownloads(for: nil))
    }

    @MainActor
    func testWhenDownloadFinishesFasterThanTempFileIsCreatedThenDownloadItemUpdated() {
    }

    @MainActor
    func testWhenDownloadFromBurnerWindowFinishesThenDownloadItemRemoved() {
        let (download, task, _) = setUpCoordinatorAndAddDownload(isBurner: true)

        let taskRemoved = expectation(description: "Task removed")
        let c = coordinator.updates.sink { update in
            XCTAssertTrue(update.item.isBurner)

            if case .removed = update.kind {
                taskRemoved.fulfill()
            }
        }

        task.downloadDidFinish(download.asWKDownload())

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertFalse(coordinator.hasActiveDownloads(for: nil))
    }

    @MainActor
    func testWhenDownloadFailsThenDownloadItemUpdatedWithError() {
        let (download, task, _) = setUpCoordinatorAndAddDownload()

        let taskCompleted = expectation(description: "location updated")
        var c: AnyCancellable!
        c = coordinator.updates.sink { update in
            if case .updated = update.kind { } else {
                XCTFail("\(update.kind) is not .updated")
            }
            guard update.item.destinationURL != nil, update.item.tempURL != nil else { return }

            XCTAssertEqual(update.item.destinationURL, self.destURL)
            XCTAssertEqual(update.item.tempURL, self.tempURL)
            XCTAssertNil(update.item.progress)
            XCTAssertEqual(update.item.error, FileDownloadError.failedToCompleteDownloadTask(underlyingError: TestError(), resumeData: .resumeData, isRetryable: true))
            XCTAssertEqual(update.item.error?.resumeData, .resumeData)
            taskCompleted.fulfill()
            c.cancel()
        }

        task.download(download.asWKDownload(), didFailWithError: TestError(), resumeData: .resumeData)

        waitForExpectations(timeout: 1)
        c = nil

        XCTAssertFalse(coordinator.hasActiveDownloads(for: nil))
    }

    @MainActor
    func testWhenPreloadedDownloadRestartedWithResumeDataThenResumeIsCalled() throws {
        var item: DownloadListItem = .testFailedItem
        item.tempURL = self.tempURL
        item.destinationURL = self.destURL
        XCTAssertTrue(fm.createFile(atPath: tempURL.path, contents: nil))
        XCTAssertTrue(fm.createFile(atPath: destURL.path, contents: nil))

        store.fetchBlock = { completionHandler in
            completionHandler(.success([item]))
        }
        setUpCoordinator()

        let resumeCalled = expectation(description: "resume called")
        webView.resumeDownloadBlock = { [testFile, tempURL] data in
            resumeCalled.fulfill()
            let resumeData = try? data.map(DownloadResumeData.init(resumeData:))
            XCTAssertEqual(resumeData?.localPath, tempURL!.path)
            XCTAssertEqual(resumeData?.tempFileName, testFile!.dropping(suffix: "." + testFile!.pathExtension).appendingPathExtension("duckload"))
            return WKDownloadMock(url: .duckDuckGo)
        }
        webView.startDownloadBlock = { _ in
            XCTFail("unexpected start call")
            return nil
        }

        let downloadAdded = expectation(description: "download addeed")
        downloadManager.addDownloadBlock = { [unowned self] download, _, destination in
            downloadAdded.fulfill()
            let task = WebKitDownloadTask(download: download, destination: destination, fireWindowSession: nil)
            if case .resume(destination: let dest, tempFile: let temp) = destination {
                XCTAssertEqual(dest.url, destURL)
                XCTAssertEqual(temp.url, tempURL)
            } else {
                XCTFail("unexpected destination: \(destination)")
            }
            return task
        }

        let itemUpdated = expectation(description: "item updated")
        let c = coordinator.updates.sink { update in
            if case .updated = update.kind { } else {
                XCTFail("\(update.kind) is not .updated")
            }
            itemUpdated.fulfill()

            XCTAssertEqual(update.item.destinationURL, item.destinationURL)
            XCTAssertEqual(update.item.tempURL, item.tempURL)
            XCTAssertNotNil(update.item.progress)
            XCTAssertNil(update.item.error)
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
        let c1 = coordinator.updates.sink { _ in
            taskFailed.fulfill()
        }
        task.download(download.asWKDownload(), didFailWithError: TestError(), resumeData: .resumeData)
        waitForExpectations(timeout: 1)
        c1.cancel()

        let resumeCalled = expectation(description: "resume called")
        webView.resumeDownloadBlock = { [testFile, tempURL] data in
            resumeCalled.fulfill()
            let resumeData = try? data.map(DownloadResumeData.init(resumeData:))
            XCTAssertEqual(resumeData?.localPath, tempURL!.path)
            XCTAssertEqual(resumeData?.tempFileName, testFile!.dropping(suffix: "." + testFile!.pathExtension).appendingPathExtension("duckload"))
            return WKDownloadMock(url: .duckDuckGo)
        }
        webView.startDownloadBlock = { _ in
            XCTFail("unexpected start call")
            return nil
        }

        let downloadAdded = expectation(description: "download addeed")
        downloadManager.addDownloadBlock = { [unowned self] download, _, destination in
            downloadAdded.fulfill()
            let task = WebKitDownloadTask(download: download, destination: destination, fireWindowSession: nil)
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
        let c = coordinator.updates.sink { update in
            if case .updated = update.kind { } else {
                XCTFail("\(update.kind) is not .updated")
            }
            itemUpdated.fulfill()

            XCTAssertEqual(update.item.destinationURL, update.item.destinationURL)
            XCTAssertEqual(update.item.tempURL, update.item.tempURL)
            XCTAssertNotNil(update.item.progress)
            XCTAssertNil(update.item.error)
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
        item.destinationURL = self.destURL
        XCTAssertTrue(fm.createFile(atPath: tempURL.path, contents: nil))
        XCTAssertTrue(fm.createFile(atPath: destURL.path, contents: nil))
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
            let task = WebKitDownloadTask(download: download, destination: destination, fireWindowSession: nil)
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
        let c = coordinator.updates.sink { update in
            if case .updated = update.kind { } else {
                XCTFail("\(update.kind) is not .updated")
            }
            itemUpdated.fulfill()

            XCTAssertEqual(update.item.destinationURL, item.destinationURL)
            XCTAssertEqual(update.item.tempURL, item.tempURL)
            XCTAssertNotNil(update.item.progress)
            XCTAssertNil(update.item.error)
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
        let c = coordinator.updates.sink { update in
            if case .removed = update.kind { } else {
                XCTFail("\(update.kind) is not .updated")
            }
            itemRemoved.fulfill()

            XCTAssertEqual(update.item.identifier, id)
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
        let (download1, task1, keptId) = setUpCoordinatorAndAddDownload()
        let destURL2 = fm.temporaryDirectory.appendingPathComponent("testfile2.pdf")
        let tempURL2 = fm.temporaryDirectory.appendingPathComponent("testfile2.duckload")
        let (download2, task2, _) = addDownload(tempURL: tempURL2, destURL: destURL2)
        let destURL3 = fm.temporaryDirectory.appendingPathComponent("myfile3.pdf")
        let tempURL3 = fm.temporaryDirectory.appendingPathComponent("myfile3.duckload")
        let (download3, task3, _) = addDownload(tempURL: tempURL3, destURL: destURL3)

        task2.download(download2.asWKDownload(), didFailWithError: TestError(), resumeData: nil)
        task3.downloadDidFinish(download3.asWKDownload())

        let e1 = expectation(description: "download stopped")
        e1.expectedFulfillmentCount = 2
        var c = coordinator.updates.sink { update in
            guard case .updated = update.kind, update.item.progress == nil else { return }
            e1.fulfill()
            XCTAssertNotEqual(update.item.identifier, keptId)
        }

        waitForExpectations(timeout: 1)

        let e2 = expectation(description: "item removed")
        e2.expectedFulfillmentCount = 2
        c = coordinator.updates.sink { update in
            guard case .removed = update.kind else { return }
            e2.fulfill()
            XCTAssertNotEqual(update.item.identifier, keptId)
        }

        coordinator.cleanupInactiveDownloads(for: nil)

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 1)
        }

        XCTAssertTrue(coordinator.hasActiveDownloads(for: nil))
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
    func testWhenDownloadTaskProgressCancelledThenTaskIsCancelled() {
        let (download, task, _) = setUpCoordinatorAndAddDownload()
        let e = expectation(description: "cancelled")
        download.cancelBlock = {
            e.fulfill()
        }
        task.progress.cancel()
        waitForExpectations(timeout: 1)
    }

    @MainActor
    func testWhenDownloadFileProgressCancelledThenTaskIsCancelled() {
        let (download, task, _) = setUpCoordinatorAndAddDownload()
        let eCancelled = expectation(description: "cancelled")
        download.cancelBlock = {
            eCancelled.fulfill()
        }

        let eProgressPopulated = expectation(description: "file progress populated")
        var timer: Timer?
        if task.fileProgress != nil {
            eProgressPopulated.fulfill()
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
                if task.fileProgress != nil {
                    eProgressPopulated.fulfill()
                    timer.invalidate()
                }
            }
        }
        wait(for: [eProgressPopulated], timeout: 2)
        timer?.invalidate()

        XCTAssertNotNil(task.fileProgress)
        task.fileProgress?.cancel()
        wait(for: [eCancelled], timeout: 1)
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
                                           fireWindowSession: nil,
                                           destinationURL: FileManager.default.temporaryDirectory.appendingPathComponent("testItem.pdf"),
                                           destinationFileBookmarkData: nil,
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
                                                 fireWindowSession: nil,
                                                 destinationURL: FileManager.default.temporaryDirectory.appendingPathComponent("oldItem.pdf"),
                                                 destinationFileBookmarkData: nil,
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
                                            fireWindowSession: nil,
                                            destinationURL: FileManager.default.temporaryDirectory.appendingPathComponent("olderItem.pdf"),
                                            destinationFileBookmarkData: nil,
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
                                                  fireWindowSession: nil,
                                                  destinationURL: URL(fileURLWithPath: "/test/path"),
                                                  destinationFileBookmarkData: nil,
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
                                                 fireWindowSession: nil,
                                                 destinationURL: FileManager.default.temporaryDirectory.appendingPathComponent("testFailedItem.pdf"),
                                                 destinationFileBookmarkData: nil,
                                                 tempURL: FileManager.default.temporaryDirectory.appendingPathComponent("testFailedItem.duckload"),
                                                 tempFileBookmarkData: nil,
                                                 error: .failedToCompleteDownloadTask(underlyingError: TestError(), resumeData: .resumeData, isRetryable: false))

}
