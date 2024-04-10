//
//  FilePresenterTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Foundation
import XCTest

@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
final class FilePresenterTests: XCTestCase {

    let fm = FileManager()
    let testData = "test data".utf8data
    let helperApp = URL(fileURLWithPath: ProcessInfo().environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"]!).appendingPathComponent("sandbox-test-tool.app")
    var runningApp: NSRunningApplication?
    var cancellables = Set<AnyCancellable>()

    var onFileRead: ((FileReadResult) -> Void)?
    var onError: ((NSError) -> Void)?

    override func setUp() async throws {
        DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.fileRead.name).sink { [unowned self] n in
            guard let onFileRead,
                  let object = n.object as? String else {
                XCTFail("❌ unexpected file read: \(n)")
                return
            }
            do {
                let result = try FileReadResult.decode(from: object)
                onFileRead(result)
            } catch {
                XCTFail("❌ could not decode FileReadResult from \(object): \(error)")
            }
        }.store(in: &cancellables)

        DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.error.name).sink { [unowned self] n in
            guard let onError,
                  let error = n.error(includingUserInfo: false) else {
                XCTFail("❌ unexpected error: \(n)")
                return
            }
            onError(error)
        }.store(in: &cancellables)
    }

    override func tearDown() async throws {
        await terminateApp()
        cancellables.removeAll()
        onError = nil
        onFileRead = nil
    }

    private func makeNonSandboxFile() throws -> URL {
        let fileName = UUID().uuidString + ".txt"
        let fileURL = fm.temporaryDirectory.appendingPathComponent(fileName)
        try testData.write(to: fileURL)

        return fileURL
    }

    private func runHelperApp(opening url: URL? = nil, newInstance: Bool = true, helloExpectation: XCTestExpectation? = XCTestExpectation(description: "hello received")) async throws -> NSRunningApplication {
        var c: AnyCancellable?
        if let helloExpectation {
            c = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.hello.name).sink { n in
                helloExpectation.fulfill()
            }
        }

        let app = if let url {
            try await NSWorkspace.shared.open([url], withApplicationAt: helperApp, configuration: .init(newInstance: newInstance, environment: [:]))
        } else {
            try await NSWorkspace.shared.openApplication(at: helperApp, configuration: .init(newInstance: newInstance, environment: [:]))
        }

        await fulfillment(of: helloExpectation.map { [$0] } ?? [], timeout: 5)
        withExtendedLifetime(c) {}

        return app
    }

    private func terminateApp(timeout: TimeInterval = 5, expectation: XCTestExpectation = XCTestExpectation(description: "terminated")) async {
        if runningApp == nil {
            expectation.fulfill()
        }
        let c = runningApp?.publisher(for: \.isTerminated).filter { $0 }.sink { _ in
            expectation.fulfill()
        }
        post(.terminate)
        runningApp?.forceTerminate()

        await fulfillment(of: [expectation], timeout: timeout)
        withExtendedLifetime(c) {}
    }

    private func post(_ name: SandboxTestNotification, with object: String? = nil) {
        DistributedNotificationCenter.default().post(name: .init(name.rawValue), object: object)
    }

    private func fileReadPromise(timeout: TimeInterval = 5, file: StaticString = #file, line: UInt = #line) -> Future<FileReadResult, Error> {
        Future<FileReadResult, Error> { [unowned self] fulfill in
            onFileRead = { result in
                fulfill(.success(result))
                self.onFileRead = nil
                self.onError = nil
            }
            onError = { error in
                fulfill(.failure(error))
                self.onFileRead = nil
                self.onError = nil
            }
        }
        .timeout(timeout, file: file, line: line)
        .first()
        .promise()
    }

    // MARK: - Test sandboxed file access
#if APPSTORE && !CI

    func testTool_run() async throws {
        // 1. make non-sandbox file
        let nonSandboxUrl = try makeNonSandboxFile()

        // 2. run the helper app
        runningApp = try await runHelperApp()

        // 3. send command to open the non-sandbox file
        let fileReadPromise = fileReadPromise()
        post(.openFileWithoutBookmark, with: nonSandboxUrl.path)

        // 4. Validate file opening failed
        do {
            let r = try await fileReadPromise.value
            XCTFail("File should be inaccessible, got \(r)")
        } catch let error as NSError {
            XCTAssertEqual(error, CocoaError(.fileReadNoPermission) as NSError)
        }
    }

    func testTool_bookmarkCreation() async throws {
        // 1. make non-sandbox file
        let nonSandboxUrl = try makeNonSandboxFile()

        // 2. open the file with the helper app
        let fileReadPromise = fileReadPromise()
        runningApp = try await runHelperApp(opening: nonSandboxUrl)

        // 3. Validate file opened successfully
        let result = try await fileReadPromise.value
        XCTAssertEqual(result.path, nonSandboxUrl.path)
        XCTAssertEqual(result.data, testData.utf8String())
        XCTAssertNotNil(result.bookmark)
    }

    func testWhenSandboxFilePresenterIsOpen_itCanReadFile_accessStoppedWhenClosed() async throws {
        // 1. make non-sandbox file; open the file and create bookmark with the helper app
        let nonSandboxUrl = try makeNonSandboxFile()
        var fileReadPromise = self.fileReadPromise()
        runningApp = try await runHelperApp(opening: nonSandboxUrl)
        guard let bookmark = try await fileReadPromise.value.bookmark else { XCTFail("No bookmark"); return }

        // 2. restart the app
        await terminateApp()
        runningApp = try await runHelperApp()

        // 3. open the bookmark with BookmarkFilePresenter
        post(.openBookmarkWithFilePresenter, with: bookmark.base64EncodedString())

        // 4. read the file
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: nonSandboxUrl.path)
        let result = try await fileReadPromise.value
        XCTAssertEqual(result.path, nonSandboxUrl.path)
        XCTAssertEqual(result.data, testData.utf8String())
        XCTAssertEqual(result.bookmark, bookmark)

        // 5. close BookmarkFilePresenter
        let e = expectation(description: "access stopped")
        let c = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.stopAccessingSecurityScopedResourceCalled.name).sink { _ in
            e.fulfill()
        }
        post(.closeFilePresenter, with: nonSandboxUrl.path)
        await fulfillment(of: [e], timeout: 1)

        withExtendedLifetime(c) {}

        // 6. Validate file reading fails
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: nonSandboxUrl.path)
        do {
            let r = try await fileReadPromise.value
            XCTFail("File should be inaccessible, got \(r)")
        } catch let error as NSError {
            XCTAssertEqual(error, CocoaError(.fileReadNoPermission) as NSError)
        }
    }

    func testWhenFileIsRenamed_accessIsPreserved() async throws {
        // 1. make non-sandbox file; open the file and create bookmark with the helper app
        let nonSandboxUrl = try makeNonSandboxFile()
        var fileReadPromise = self.fileReadPromise()
        runningApp = try await runHelperApp(opening: nonSandboxUrl)
        guard let bookmark = try await fileReadPromise.value.bookmark else { XCTFail("No bookmark"); return }

        // 2. restart the app
        await terminateApp()
        runningApp = try await runHelperApp()

        // 3. open the bookmark with BookmarkFilePresenter
        post(.openBookmarkWithFilePresenter, with: bookmark.base64EncodedString())
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: nonSandboxUrl.path)
        _=try await fileReadPromise.value

        // 4.a rename the file
        let newUrl = nonSandboxUrl.deletingPathExtension().appendingPathExtension("1.txt")
        let e1 = expectation(description: "file presenter: file renamed")
        var c1 = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.fileMoved.name).sink { n in
            XCTAssertEqual(newUrl.path, n.object as? String)
            e1.fulfill()
        }
        let e2 = expectation(description: "file presenter: bookmark updated")
        var c2 = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.fileBookmarkDataUpdated.name).sink { n in
            e2.fulfill()
        }

        try NSFileCoordinator().coordinateMove(from: nonSandboxUrl, to: newUrl) { from, to in
            try FileManager.default.moveItem(at: from, to: to)
        }
        await fulfillment(of: [e1, e2], timeout: 5)

        // 4.b rename the file twice
        let newUrl2 = nonSandboxUrl.deletingPathExtension().appendingPathExtension("2.txt")
        let e3 = expectation(description: "file presenter: file renamed 2")
        c1 = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.fileMoved.name).sink { n in
            XCTAssertEqual(newUrl2.path, n.object as? String)
            e3.fulfill()
        }
        let e4 = expectation(description: "file presenter: bookmark updated 2")
        var newFileBookmarkData: Data?
        c2 = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.fileBookmarkDataUpdated.name).sink { n in
            newFileBookmarkData = (n.object as? String).flatMap { Data(base64Encoded: $0) }
            e4.fulfill()
        }

        try NSFileCoordinator().coordinateMove(from: newUrl, to: newUrl2) { from, to in
            try FileManager.default.moveItem(at: from, to: to)
        }
        await fulfillment(of: [e3, e4], timeout: 5)
        withExtendedLifetime((c1, c2)) {}

        // 5. read the renamed file
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: newUrl2.path)
        let result = try await fileReadPromise.value
        XCTAssertEqual(result.path, newUrl2.path)
        XCTAssertEqual(result.data, testData.utf8String())
        // bookmark should update
        XCTAssertNotNil(result.bookmark)
        XCTAssertNotEqual(result.bookmark, bookmark)
        XCTAssertEqual(result.bookmark, newFileBookmarkData)
    }

    func testWhenFileIsRenamed_renamedFileCanBeRead() async throws {
        // 1. make non-sandbox file; open the file and create bookmark with the helper app
        let nonSandboxUrl = try makeNonSandboxFile()
        var fileReadPromise = self.fileReadPromise()
        runningApp = try await runHelperApp(opening: nonSandboxUrl)
        guard let bookmark = try await fileReadPromise.value.bookmark else { XCTFail("No bookmark"); return }

        // 2. rename the file
        let newUrl = nonSandboxUrl.deletingPathExtension().appendingPathExtension("1.txt")
        try FileManager.default.moveItem(at: nonSandboxUrl, to: newUrl)

        // 3. restart the app
        await terminateApp()
        runningApp = try await runHelperApp()

        // 3. open the bookmark with BookmarkFilePresenter
        post(.openBookmarkWithFilePresenter, with: bookmark.base64EncodedString())
        fileReadPromise = self.fileReadPromise()

        // 4. read the renamed file
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: newUrl.path)
        let result = try await fileReadPromise.value
        XCTAssertEqual(result.path, newUrl.path)
        XCTAssertEqual(result.data, testData.utf8String())
        // bookmark should update
        XCTAssertNotNil(result.bookmark)
        XCTAssertNotEqual(result.bookmark, bookmark)
    }

    func testWhenFileIsMovedToTrash_moveIsDetected() async throws {
        // 1. make non-sandbox file; open the file and create bookmark with the helper app
        let nonSandboxUrl = try makeNonSandboxFile()
        var fileReadPromise = self.fileReadPromise()
        runningApp = try await runHelperApp(opening: nonSandboxUrl)
        guard let bookmark = try await fileReadPromise.value.bookmark else { XCTFail("No bookmark"); return }

        // 2. restart the app
        await terminateApp()
        runningApp = try await runHelperApp()

        // 3. open the bookmark with BookmarkFilePresenter
        post(.openBookmarkWithFilePresenter, with: bookmark.base64EncodedString())
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: nonSandboxUrl.path)
        _=try await fileReadPromise.value

        // 4. rename the file
        var newUrl: NSURL?
        let e1 = expectation(description: "file presenter: file renamed")
        let c1 = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.fileMoved.name).sink { n in
            XCTAssertNotNil(newUrl)
            XCTAssertEqual(newUrl?.path, n.object as? String)
            e1.fulfill()
        }
        let e2 = expectation(description: "file presenter: bookmark updated")
        let c2 = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.fileBookmarkDataUpdated.name).sink { n in
            XCTAssertNotNil((n.object as? String).flatMap { Data(base64Encoded: $0) })
            e2.fulfill()
        }

        try NSFileCoordinator().coordinateWrite(at: nonSandboxUrl, with: .forMoving) { url in
            try FileManager.default.trashItem(at: url, resultingItemURL: &newUrl)
        }
        await fulfillment(of: [e1, e2], timeout: 5)

        withExtendedLifetime((c1, c2)) {}
    }

    func testWhenSandboxFilePresenterIsOpenAndFileIsRenamed_accessStoppedWhenClosed() async throws {
        // 1. make non-sandbox file; open the file and create bookmark with the helper app
        let nonSandboxUrl = try makeNonSandboxFile()
        var fileReadPromise = self.fileReadPromise()
        runningApp = try await runHelperApp(opening: nonSandboxUrl)
        guard let bookmark = try await fileReadPromise.value.bookmark else { XCTFail("No bookmark"); return }

        // 2. restart the app
        await terminateApp()
        runningApp = try await runHelperApp()

        // 3. open the bookmark with BookmarkFilePresenter
        post(.openBookmarkWithFilePresenter, with: bookmark.base64EncodedString())
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: nonSandboxUrl.path)
        _=try await fileReadPromise.value

        // 4. rename the file
        let newUrl = nonSandboxUrl.deletingPathExtension().appendingPathExtension("1.txt")
        let e = expectation(description: "file presenter: file renamed")
        let c = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.fileMoved.name).sink { n in
            XCTAssertEqual(newUrl.path, n.object as? String)
            e.fulfill()
        }

        try NSFileCoordinator().coordinateMove(from: nonSandboxUrl, to: newUrl) { from, to in
            try FileManager.default.moveItem(at: from, to: to)
        }
        await fulfillment(of: [e], timeout: 5)

        // 5. close BookmarkFilePresenter
        let eStopped = expectation(description: "access stopped")
        let c2 = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.stopAccessingSecurityScopedResourceCalled.name).sink { _ in
            eStopped.fulfill()
        }
        post(.closeFilePresenter, with: nonSandboxUrl.path)
        await fulfillment(of: [eStopped], timeout: 1)

        withExtendedLifetime((c, c2)) {}

        // 6. Validate file reading fails
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: newUrl.path)
        do {
            let r = try await fileReadPromise.value
            XCTFail("File should be inaccessible, got \(r)")
        } catch let error as NSError {
            XCTAssertEqual(error, CocoaError(.fileReadNoPermission) as NSError)
        }
    }

    func testWhenSandboxFilePresenterIsClosed_fileRenameIsNotDetected() async throws {
        // 1. make non-sandbox file; open the file and create bookmark with the helper app
        let nonSandboxUrl = try makeNonSandboxFile()
        var fileReadPromise = self.fileReadPromise()
        runningApp = try await runHelperApp(opening: nonSandboxUrl)
        guard let bookmark = try await fileReadPromise.value.bookmark else { XCTFail("No bookmark"); return }

        // 2. restart the app
        await terminateApp()
        runningApp = try await runHelperApp()

        // 3. open the bookmark with BookmarkFilePresenter
        post(.openBookmarkWithFilePresenter, with: bookmark.base64EncodedString())
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: nonSandboxUrl.path)
        _=try await fileReadPromise.value

        // 4. close BookmarkFilePresenter
        let eStopped = expectation(description: "access stopped")
        let c2 = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.stopAccessingSecurityScopedResourceCalled.name).sink { _ in
            eStopped.fulfill()
        }
        post(.closeFilePresenter, with: nonSandboxUrl.path)
        await fulfillment(of: [eStopped], timeout: 1)

        // 5. rename the file
        let newUrl = nonSandboxUrl.deletingPathExtension().appendingPathExtension("1.txt")
        let e = expectation(description: "file presenter: file renamed - should not be fulfilled")
        e.isInverted = true
        let c = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.fileMoved.name).sink { n in
            e.fulfill()
        }
        try NSFileCoordinator().coordinateMove(from: nonSandboxUrl, to: newUrl) { from, to in
            try FileManager.default.moveItem(at: from, to: to)
        }

        // 6. Validate file reading fails
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: newUrl.path)
        do {
            let r = try await fileReadPromise.value
            XCTFail("File should be inaccessible, got \(r)")
        } catch let error as NSError {
            XCTAssertEqual(error, CocoaError(.fileReadNoPermission) as NSError)
        }
        // file renamed callback shouldn‘t be called (e is inverted)
        await fulfillment(of: [e], timeout: 0)
        withExtendedLifetime((c, c2)) {}
    }

    func testWhenFileIsRenamedAndRecreatedWithOriginalName_fileIsNotAccessible() async throws {
        // 1. make non-sandbox file; open the file and create bookmark with the helper app
        let nonSandboxUrl = try makeNonSandboxFile()
        var fileReadPromise = self.fileReadPromise()
        runningApp = try await runHelperApp(opening: nonSandboxUrl)
        guard let bookmark = try await fileReadPromise.value.bookmark else { XCTFail("No bookmark"); return }

        // 2. restart the app
        await terminateApp()
        runningApp = try await runHelperApp()

        // 3. open the bookmark with BookmarkFilePresenter
        post(.openBookmarkWithFilePresenter, with: bookmark.base64EncodedString())
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: nonSandboxUrl.path)
        _=try await fileReadPromise.value

        // 4. rename the file
        let newUrl = nonSandboxUrl.deletingPathExtension().appendingPathExtension("1.txt")
        let e = expectation(description: "file presenter: file renamed")
        let c = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.fileMoved.name).sink { n in
            XCTAssertEqual(newUrl.path, n.object as? String)
            e.fulfill()
        }

        try NSFileCoordinator().coordinateMove(from: nonSandboxUrl, to: newUrl) { from, to in
            try FileManager.default.moveItem(at: from, to: to)
        }
        await fulfillment(of: [e], timeout: 5)

        // 5. create a new file with original name
        try testData.write(to: nonSandboxUrl)

        // 6. read the re-created file - should fail
        fileReadPromise = self.fileReadPromise()

        post(.openFile, with: nonSandboxUrl.path)
        do {
            let r = try await fileReadPromise.value
            XCTFail("File should be inaccessible, got \(r)")
        } catch let error as NSError {
            XCTAssertEqual(error, CocoaError(.fileReadNoPermission) as NSError)
        }

        withExtendedLifetime(c) {}
    }

    func testWhenFileIsRemoved_removalIsDetected() async throws {
        // 1. make non-sandbox file; open the file and create bookmark with the helper app
        let nonSandboxUrl = try makeNonSandboxFile()
        var fileReadPromise = self.fileReadPromise()
        runningApp = try await runHelperApp(opening: nonSandboxUrl)
        guard let bookmark = try await fileReadPromise.value.bookmark else { XCTFail("No bookmark"); return }

        // 2. restart the app
        await terminateApp()
        runningApp = try await runHelperApp()

        // 3. open the bookmark with BookmarkFilePresenter
        post(.openBookmarkWithFilePresenter, with: bookmark.base64EncodedString())
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: nonSandboxUrl.path)
        _=try await fileReadPromise.value

        // 4. remove the file
        let e1 = expectation(description: "file presenter: file removed")
        let e2 = expectation(description: "file presenter: bookmark updated")
        let c1 = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.fileMoved.name).sink { n in
            XCTAssertNil(n.object)
            e1.fulfill()
        }
        let c2 = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.fileBookmarkDataUpdated.name).sink { n in
            XCTAssertNil(n.object)
            e2.fulfill()
        }

        try NSFileCoordinator().coordinateWrite(at: nonSandboxUrl, with: .forDeleting) { url in
            try FileManager.default.removeItem(at: url)
        }
        await fulfillment(of: [e1, e2], timeout: 5)
        withExtendedLifetime((c1, c2)) {}
    }

    func testWhen2FilesAreCrossRenamedAnd1stFileClosed_accessTo2ndIsPreserved() async throws {
        // 1. make 2 non-sandbox files; open the files and create bookmarks with the helper app
        let nonSandboxUrl1 = try makeNonSandboxFile()
        let nonSandboxUrl2 = try makeNonSandboxFile()
        var fileReadPromise = self.fileReadPromise()
        runningApp = try await runHelperApp(opening: nonSandboxUrl1)
        guard let bookmark1 = try await fileReadPromise.value.bookmark else { XCTFail("No bookmark"); return }
        fileReadPromise = self.fileReadPromise()
        _=try await runHelperApp(opening: nonSandboxUrl2, newInstance: false, helloExpectation: nil)
        guard let bookmark2 = try await fileReadPromise.value.bookmark else { XCTFail("No bookmark"); return }

        // 2. restart the app
        await terminateApp()
        runningApp = try await runHelperApp()

        // 3. open the bookmark with BookmarkFilePresenter
        post(.openBookmarkWithFilePresenter, with: bookmark1.base64EncodedString())
        post(.openBookmarkWithFilePresenter, with: bookmark2.base64EncodedString())
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: nonSandboxUrl1.path)
        _=try await fileReadPromise.value
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: nonSandboxUrl2.path)
        _=try await fileReadPromise.value

        // 4. cross-rename the files
        let tempUrl = nonSandboxUrl1.appendingPathExtension("tmp")
        for (from, to) in [(nonSandboxUrl1, tempUrl), (nonSandboxUrl2, nonSandboxUrl1), (tempUrl, nonSandboxUrl2)] {
            let e = expectation(description: "file presenter: file renamed")
            let c = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.fileMoved.name).sink { n in
                XCTAssertEqual(to.path, n.object as? String)
                e.fulfill()
            }
            try NSFileCoordinator().coordinateMove(from: from, to: to) { from, to in
                try FileManager.default.moveItem(at: from, to: to)
            }
            await fulfillment(of: [e], timeout: 5)
            withExtendedLifetime(c) {}
        }

        // 5. close FilePresenter 1 (at the original URL)
        let e3 = expectation(description: "access stopped")
        let c2 = DistributedNotificationCenter.default().publisher(for: SandboxTestNotification.stopAccessingSecurityScopedResourceCalled.name).sink { n in
            e3.fulfill()
        }
        post(.closeFilePresenter, with: nonSandboxUrl1.path)
        await fulfillment(of: [e3], timeout: 1)

        withExtendedLifetime(c2) {}

        // 6.a validate 2nd file (renamed to nonSandboxUrl1) can still be accessed
        fileReadPromise = self.fileReadPromise()
        post(.openFile, with: nonSandboxUrl1.path)
        let result = try await fileReadPromise.value
        XCTAssertEqual(result.path, nonSandboxUrl1.path)
        XCTAssertEqual(result.data, testData.utf8String())
        // bookmark should update
        XCTAssertNotNil(result.bookmark)

        // 6.b 1st file read should fail
        fileReadPromise = self.fileReadPromise()

        post(.openFile, with: nonSandboxUrl2.path)
        do {
            let r = try await fileReadPromise.value
            XCTFail("File should be inaccessible, got \(r)")
        } catch let error as NSError {
            XCTAssertEqual(error, CocoaError(.fileReadNoPermission) as NSError)
        }
    }

#endif

    // MARK: - Test non-sandboxed file access

    func testWhenSandboxFilePresenterIsOpen_itCanReadFile_accessIsNotStoppedWhenClosed_noSandbox() async throws {
        // 1. make non-sandbox file; create bookmark
        let nonSandboxUrl = try makeNonSandboxFile()
        guard let bookmarkData = try BookmarkFilePresenter(url: nonSandboxUrl).fileBookmarkData else { XCTFail("No bookmark"); return }

        // 2. open the bookmark with BookmarkFilePresenter
        var filePresenter: BookmarkFilePresenter! = try BookmarkFilePresenter(fileBookmarkData: bookmarkData)

        // 3. validate
        var publishedUrl: URL?
        _=filePresenter.urlPublisher.sink { publishedUrl = $0 }
        var publishedBookmarkData: Data?
        _=filePresenter.fileBookmarkDataPublisher.sink { publishedBookmarkData = $0 }
        XCTAssertEqual(filePresenter.url?.resolvingSymlinksInPath(), nonSandboxUrl.resolvingSymlinksInPath())
        XCTAssertEqual(publishedUrl?.resolvingSymlinksInPath(), nonSandboxUrl.resolvingSymlinksInPath())
        XCTAssertEqual(filePresenter.fileBookmarkData, bookmarkData)
        XCTAssertEqual(publishedBookmarkData, bookmarkData)

        // 4. close file presenter, access should not stop
        filePresenter = nil
        XCTAssertEqual(try Data(contentsOf: nonSandboxUrl), testData)
    }

    func testWhenFileIsRenamed_urlIsUpdated_noSandbox() async throws {
        // 1. make non-sandbox file
        let nonSandboxUrl = try makeNonSandboxFile()
        let filePresenter = try BookmarkFilePresenter(url: nonSandboxUrl)

        // 4. rename the file
        let newUrl = nonSandboxUrl.deletingPathExtension().appendingPathExtension("1.txt")
        let e1 = expectation(description: "file presenter: file renamed")
        let c1 = filePresenter.urlPublisher.dropFirst().sink { url in
            XCTAssertEqual(newUrl, url)
            e1.fulfill()
        }
        let e2 = expectation(description: "file presenter: bookmark updated")
        var newFileBookmarkData: Data?
        let c2 = filePresenter.fileBookmarkDataPublisher.dropFirst().sink { bookmark in
            newFileBookmarkData = bookmark
            e2.fulfill()
        }

        try NSFileCoordinator().coordinateMove(from: nonSandboxUrl, to: newUrl) { from, to in
            try FileManager.default.moveItem(at: from, to: to)
        }
        await fulfillment(of: [e1, e2], timeout: 5)
        withExtendedLifetime((c1, c2)) {}

        let bookmarkData = try newUrl.bookmarkData(options: .withSecurityScope)

        // url&bookmark should update
        XCTAssertEqual(filePresenter.url, newUrl)
        XCTAssertEqual(filePresenter.fileBookmarkData, bookmarkData)
        XCTAssertEqual(newFileBookmarkData, bookmarkData)
    }

    func testWhenFileIsRemoved_removalIsDetected_noSandbox() async throws {
        // 1. make non-sandbox file
        let nonSandboxUrl = try makeNonSandboxFile()
        let filePresenter = try BookmarkFilePresenter(url: nonSandboxUrl)

        // 2. remove the file
        let e1 = expectation(description: "file presenter: file removed")
        let e2 = expectation(description: "file presenter: bookmark updated")
        let c1 = filePresenter.urlPublisher.dropFirst().sink { url in
            XCTAssertNil(url)
            e1.fulfill()
        }
        let c2 = filePresenter.fileBookmarkDataPublisher.dropFirst().sink { bookmark in
            XCTAssertNil(bookmark)
            e2.fulfill()
        }

        try NSFileCoordinator().coordinateWrite(at: nonSandboxUrl, with: .forDeleting) { url in
            try FileManager.default.removeItem(at: url)
        }
        await fulfillment(of: [e1, e2], timeout: 5)
        withExtendedLifetime((c1, c2)) {}
    }

    func testWhen2FilesAreCrossRenamedAnd1stFileClosed_accessTo2ndIsPreserved_noSandbox() async throws {
        // 1. make 2 non-sandbox files
        let nonSandboxUrl1 = try makeNonSandboxFile()
        let bookmarkData1 = try nonSandboxUrl1.bookmarkData(options: .withSecurityScope)
        let nonSandboxUrl2 = try makeNonSandboxFile()
        let bookmarkData2 = try nonSandboxUrl2.bookmarkData(options: .withSecurityScope)
        let filePresenter1 = try BookmarkFilePresenter(fileBookmarkData: bookmarkData1)
        let filePresenter2 = try BookmarkFilePresenter(fileBookmarkData: bookmarkData2)

        // 2. cross-rename the files
        let tempUrl = nonSandboxUrl1.appendingPathExtension("tmp")
        var newBookmarkData1: Data?
        var newBookmarkData2: Data?
        for (from, to, presenter) in [(nonSandboxUrl1, tempUrl, filePresenter1), (nonSandboxUrl2, nonSandboxUrl1, filePresenter2), (tempUrl, nonSandboxUrl2, filePresenter1)] {
            let e1 = expectation(description: "file presenter: file renamed")
            let c1 = presenter.urlPublisher.dropFirst().sink { [unowned presenter] url in
                XCTAssertEqual(url, presenter.url)
                XCTAssertEqual(to, url)
                e1.fulfill()
            }
            let e2 = expectation(description: "file presenter: bookmark updated")
            let c2 = presenter.fileBookmarkDataPublisher.dropFirst().sink { [unowned presenter] bookmarkData in
                XCTAssertEqual(bookmarkData, presenter.fileBookmarkData)
                if presenter === filePresenter1 {
                    newBookmarkData1 = bookmarkData
                } else {
                    newBookmarkData2 = bookmarkData
                }
                e2.fulfill()
            }
            let c3 = ((presenter === filePresenter1) ? filePresenter2 : filePresenter1).urlPublisher.dropFirst().sink { _ in
                XCTFail("Unexpected url published from another file presenter")
            }
            try NSFileCoordinator().coordinateMove(from: from, to: to) { from, to in
                try FileManager.default.moveItem(at: from, to: to)
            }
            await fulfillment(of: [e1, e2], timeout: 5)
            withExtendedLifetime((c1, c2, c3)) {}
        }

        XCTAssertEqual(filePresenter1.url, nonSandboxUrl2)
        XCTAssertEqual(filePresenter2.url, nonSandboxUrl1)
        var isStale = false
        XCTAssertEqual(newBookmarkData1, filePresenter1.fileBookmarkData)
        XCTAssertEqual(try URL(resolvingBookmarkData: filePresenter1.fileBookmarkData ?? Data(), bookmarkDataIsStale: &isStale).resolvingSymlinksInPath(),
                       nonSandboxUrl2.resolvingSymlinksInPath())
        // XCTAssertFalse(isStale) - why it‘s false?
        XCTAssertEqual(newBookmarkData2, filePresenter2.fileBookmarkData)
        XCTAssertEqual(try URL(resolvingBookmarkData: filePresenter2.fileBookmarkData ?? Data(), bookmarkDataIsStale: &isStale).resolvingSymlinksInPath(),
                       nonSandboxUrl1.resolvingSymlinksInPath())
        // XCTAssertFalse(isStale) - why it‘s false?
    }

}

private extension Notification {
    func error(includingUserInfo: Bool = true) -> NSError? {
        guard let object = object as? String,
              let dict = try? JSONSerialization.jsonObject(with: object.utf8data) as? [String: Any],
              let domain = dict[UserInfoKeys.errorDomain] as? String,
              let code = dict[UserInfoKeys.errorCode] as? Int
        else { return nil }
        if includingUserInfo {
            return NSError(domain: domain, code: code, userInfo: dict)
        }
        return NSError(domain: domain, code: code)
    }
}
