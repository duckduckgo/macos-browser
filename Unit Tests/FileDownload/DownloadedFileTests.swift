//
//  DownloadedFileTests.swift
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
final class DownloadedFileTests: XCTestCase {

    let testFile = "downloaded file "
    let fm = FileManager.default

    override func setUp() {
        let tempDir = fm.temporaryDirectory
        for file in (try? fm.contentsOfDirectory(atPath: tempDir.path)) ?? [] where file.hasPrefix(testFile) {
            try? fm.removeItem(at: tempDir.appendingPathComponent(file))
        }
    }
    override func tearDown() {
        NSURL.restoreInitByResolvingBookmarkData()
        NSURLMock.resourceValuesForKeysReplacement = [:]
    }

    func getURL() -> URL {
        (fm.temporaryDirectory as NSURL).fileReferenceURL()!.appendingPathComponent(testFile + .uniqueFilename())
    }

    func testFileOpen() throws {
        let url = getURL()
        let file = try DownloadedFile(url: url)

        XCTAssertEqual(file.url, url)
        XCTAssertEqual(file.bytesWritten, 0)
    }

    func testDownloadedFileDeallocation() throws {
        var file: DownloadedFile? = try DownloadedFile(url: getURL())
        weak var weakFile = file

        file = nil
        XCTAssertNil(weakFile)
    }

    func testFileWriteSequence() throws {
        let file = try DownloadedFile(url: getURL())
        let dataArray = [
            "the ".data(using: .utf8)!,
            "file ".data(using: .utf8)!,
            "content".data(using: .utf8)!
        ]

        for data in dataArray {
            file.write(data)
        }

        _=try file.move(to: file.url!, incrementingIndexIfExists: false) // synchronize

        let result = try Data(contentsOf: file.url!)
        let expected = dataArray.reduce(Data(), +)

        XCTAssertEqual(Int(file.bytesWritten), result.count)
        XCTAssertEqual(result, expected)
    }

    func testFileWriteSequenceWithAsyncMove() throws {
        let file = try DownloadedFile(url: getURL())
        let dataArray = [
            "the ".data(using: .utf8)!,
            "file ".data(using: .utf8)!,
            "content".data(using: .utf8)!
        ]

        for data in dataArray {
            file.write(data)
        }

        let e = expectation(description: "file moved")
        file.asyncMove(to: file.url!, incrementingIndexIfExists: false) { _ in
            let result = try? Data(contentsOf: file.url!)
            let expected = dataArray.reduce(Data(), +)

            XCTAssertEqual(Int(file.bytesWritten), result?.count)
            XCTAssertEqual(result, expected)

            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testWhenFileAppendedThenBytesWrittenSubjectUpdates() throws {
        let file = try DownloadedFile(url: getURL())
        let dataArray = [
            "the ".data(using: .utf8)!,
            "file ".data(using: .utf8)!,
            "content".data(using: .utf8)!
        ]
        let expectations = ([Data()] + dataArray).reduce(into: (0, [Int: XCTestExpectation]())) {
            $0.0 += $1.count
            $0.1[$0.0] = expectation(description: "received bytesWritten \($0.0)")
        }.1

        let cancellable = file.$bytesWritten.sink { value in
            expectations[Int(value)]!.fulfill()
        }

        for data in dataArray {
            file.write(data)
        }

        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 1)
        }
    }

    func testWhenExistingFileOpenThenItsContentIsOverwritten() throws {
        let url = getURL()
        try "some longer file content that is overwritten".data(using: .utf8)!
            .write(to: url)

        let file = try DownloadedFile(url: url)

        XCTAssertEqual(file.bytesWritten, 0)

        let data = "overwritten content".data(using: .utf8)!
        file.write(data)

        _=try file.move(to: file.url!, incrementingIndexIfExists: false) // synchronize

        let result = try Data(contentsOf: file.url!)
        let expected = data

        XCTAssertEqual(Int(file.bytesWritten), result.count)
        XCTAssertEqual(result, expected)
    }

    func testWhenExistingFileOpenWithForAppendingItsContentIsAppended() throws {
        let url = getURL()
        let origData = "some longer file content that is overwritten ".data(using: .utf8)!
        try origData.write(to: url)

        let file = try DownloadedFile(url: url, offset: UInt64(origData.count))

        XCTAssertEqual(Int(file.bytesWritten), origData.count)

        let appendedData = "appended content".data(using: .utf8)!
        file.write(appendedData)

        _=try file.move(to: file.url!, incrementingIndexIfExists: false) // synchronize

        let result = try Data(contentsOf: file.url!)
        let expected = origData + appendedData

        XCTAssertEqual(Int(file.bytesWritten), result.count)
        XCTAssertEqual(result, expected)
    }

    func testWhenExistingFileOpenWithOffsetItsContentIsAppendedFromOffset() throws {
        let url = getURL()
        let origData = "some longer file content that is overwritten ".data(using: .utf8)!
        try origData.write(to: url)

        let file = try DownloadedFile(url: url, offset: 5)

        XCTAssertEqual(Int(file.bytesWritten), 5)

        let appendedData = "appended content".data(using: .utf8)!
        file.write(appendedData)

        _=try file.move(to: file.url!, incrementingIndexIfExists: false) // synchronize

        let result = try Data(contentsOf: file.url!)
        let expected = "some appended content".data(using: .utf8)!

        XCTAssertEqual(Int(file.bytesWritten), result.count)
        XCTAssertEqual(result, expected)
    }

    func testWhenExistingFileOpenWithInvalidOffsetThenOffsetIsZero() throws {
        let url = getURL()
        let origData = "some longer file content that is overwritten ".data(using: .utf8)!
        try origData.write(to: url)

        let file = try DownloadedFile(url: url, offset: UInt64(origData.count + 1))

        XCTAssertEqual(file.bytesWritten, 0)

        let appendedData = "appended content".data(using: .utf8)!
        file.write(appendedData)

        _=try file.move(to: file.url!, incrementingIndexIfExists: false) // synchronize

        let result = try Data(contentsOf: file.url!)
        let expected = appendedData

        XCTAssertEqual(Int(file.bytesWritten), result.count)
        XCTAssertEqual(result, expected)
    }

    func testWhenFileDeletedThenFileDoesNotExist() throws {
        let url = getURL()
        let file = try DownloadedFile(url: url)

        file.write("some ".data(using: .utf8)!)

        file.delete()

        file.write("file content".data(using: .utf8)!)

        XCTAssertThrowsError(try file.move(to: url, incrementingIndexIfExists: false))
        XCTAssertFalse(fm.fileExists(atPath: url.path))
    }

    func testWhenFileIsMovedThenWritingContinues() throws {
        let url1 = getURL()
        let url2 = getURL()
        let file = try DownloadedFile(url: url1)

        let origData = "some ".data(using: .utf8)!
        file.write(origData)

        let moveResult = try file.move(to: url2, incrementingIndexIfExists: false)
        XCTAssertEqual(moveResult, url2)
        XCTAssertEqual(file.url, url2)

        let appendedData = "file content".data(using: .utf8)!
        file.write(appendedData)

        _=try file.move(to: file.url!, incrementingIndexIfExists: false) // synchronize

        let result = try Data(contentsOf: file.url!)
        let expected = origData + appendedData

        XCTAssertEqual(Int(file.bytesWritten), result.count)
        XCTAssertEqual(result, expected)
    }

    func testWhenFileIsMovedWithFileManagerThenURLIsPublishedAndWritingContinues() throws {
        let url1 = getURL()
        let url2 = getURL()
        let file = try DownloadedFile(url: url1)

        let expectations = [
            url1.path: expectation(description: "received original URL"),
            url2.path: expectation(description: "received new URL")
        ]
        let cancellable = file.$url.sink { url in
            expectations[(url! as NSURL).fileReferenceURL()!.path]!.fulfill()
        }

        let origData = "some ".data(using: .utf8)!
        file.write(origData)

        try fm.moveItem(at: url1, to: url2)

        let appendedData = "file content".data(using: .utf8)!
        file.write(appendedData)

        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 1)
        }
        _=try file.move(to: file.url!, incrementingIndexIfExists: false) // synchronize

        let result = try Data(contentsOf: file.url!)
        let expected = origData + appendedData

        XCTAssertEqual(file.url, url2)
        XCTAssertEqual(Int(file.bytesWritten), result.count)
        XCTAssertEqual(result, expected)
    }

    func testWhenFileIsRenamedThenWritingContinues() throws {
        let url1 = getURL()
        let url2 = getURL()

        let file = try DownloadedFile(url: url1)

        let origData = "data ".data(using: .utf8)!
        file.write(origData)

        try fm.moveItem(at: url1, to: url2)

        let appendedData = "appended".data(using: .utf8)!
        file.write(appendedData)

        _=try file.move(to: url2, incrementingIndexIfExists: false) // synchronize

        let result = try Data(contentsOf: file.url!)
        let expected = origData + appendedData

        XCTAssertEqual(file.url, url2)
        XCTAssertEqual(Int(file.bytesWritten), result.count)
        XCTAssertEqual(result, expected)
    }

    func testWhenFileIsMovedBetweenVolumesThenWritingFails() throws {
        let url1 = getURL()
        let url2 = NSURLMock(fileURLWithPath: getURL().path) as URL
        let syncQueue = DispatchQueue(label: "testWhenFileIsMovedBetweenVolumesThenWritingContinues.queue")

        let e1 = expectation(description: "should resolve bookmark data")
        NSURL.swizzleInitByResolvingBookmarkData {
            syncQueue.sync {
                e1.fulfill()
                return url2 as NSURL
            }
        }
        NSURLMock.resourceValuesForKeysReplacement[.volumeURLKey] = url2.pathComponents.first!

        let file = try DownloadedFile(url: url1)

        let e2 = expectation(description: "url should receive nil")
        let cancellable = file.$url.sink { url in
            if url == nil {
                e2.fulfill()
            }
        }

        let origData = "data ".data(using: .utf8)!
        file.write(origData)

        // simulate moving to another volume
        try syncQueue.sync {
            let data = try Data(contentsOf: url1)
            try fm.removeItem(at: url1)
            fm.createFile(atPath: url2.path, contents: data, attributes: nil)
        }

        let appendedData = "appended".data(using: .utf8)!
        file.write(appendedData)

        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertThrowsError(try file.move(to: url2, incrementingIndexIfExists: false))
        XCTAssertNil(file.url)
    }

    func testWhenFileIsMovedBetweenVolumesThenAsyncMoveFails() throws {
        let url1 = getURL()
        let url2 = NSURLMock(fileURLWithPath: getURL().path) as URL
        let syncQueue = DispatchQueue(label: "testWhenFileIsMovedBetweenVolumesThenWritingContinues.queue")

        let e1 = expectation(description: "should resolve bookmark data")
        NSURL.swizzleInitByResolvingBookmarkData {
            syncQueue.sync {
                e1.fulfill()
                return url2 as NSURL
            }
        }
        NSURLMock.resourceValuesForKeysReplacement[.volumeURLKey] = url2.pathComponents.first!

        let file = try DownloadedFile(url: url1)

        let e2 = expectation(description: "url should receive nil")
        let cancellable = file.$url.sink { url in
            if url == nil {
                e2.fulfill()
            }
        }

        let origData = "data ".data(using: .utf8)!
        file.write(origData)

        // simulate moving to another volume
        try syncQueue.sync {
            let data = try Data(contentsOf: url1)
            try fm.removeItem(at: url1)
            fm.createFile(atPath: url2.path, contents: data, attributes: nil)
        }

        let appendedData = "appended".data(using: .utf8)!
        file.write(appendedData)

        let e3 = expectation(description: "move fails")
        file.asyncMove(to: url2, incrementingIndexIfExists: false) { result in
            if case .failure = result {} else {
                XCTFail("unexpected result \(result)")
            }
            e3.fulfill()
        }

        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 1)
        }
        XCTAssertNil(file.url)
    }

}

private extension NSURL {
    private static var nextBookmarkResolutionPath: (() -> NSURL)!
    private static var isSwizzled = false
    private static let originalInitByResolvingBookmarkData = {
        class_getInstanceMethod(NSURL.self, #selector(NSURL.init(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)))!
    }()
    private static let swizzledInitByResolvingBookmarkData = {
        class_getInstanceMethod(NSURL.self, #selector(NSURL.swizzled_init(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)))!
    }()

    static func swizzleInitByResolvingBookmarkData(with resolve: @escaping (() -> NSURL)) {
        if !self.isSwizzled {
            self.isSwizzled = true
            method_exchangeImplementations(originalInitByResolvingBookmarkData, swizzledInitByResolvingBookmarkData)
        }
        self.nextBookmarkResolutionPath = resolve
    }

    static func restoreInitByResolvingBookmarkData() {
        if self.isSwizzled {
            self.isSwizzled = false
            method_exchangeImplementations(originalInitByResolvingBookmarkData, swizzledInitByResolvingBookmarkData)
        }
        self.nextBookmarkResolutionPath = nil
    }

    @objc(swizzled_initByResolvingBookmarkData:options:relativeToURL:bookmarkDataIsStale:error:)
    func swizzled_init(resolvingBookmarkData bookmarkData: Data,
                       options: NSURL.BookmarkResolutionOptions = [],
                       relativeTo relativeURL: URL?,
                       bookmarkDataIsStale isStale: UnsafeMutablePointer<ObjCBool>?) throws -> NSURL {

        Unmanaged<NSURL>.passRetained(Self.nextBookmarkResolutionPath()).takeUnretainedValue()
    }

}

private class NSURLMock: NSURL {
    static var resourceValuesForKeysReplacement = [URLResourceKey: Any]()
    override func resourceValues(forKeys keys: [URLResourceKey]) throws -> [URLResourceKey: Any] {
        var resourceValues = try super.resourceValues(forKeys: keys)
        for (key, replacementValue) in Self.resourceValuesForKeysReplacement where resourceValues[key] != nil {
            resourceValues[key] = replacementValue
        }
        return resourceValues
    }
}
