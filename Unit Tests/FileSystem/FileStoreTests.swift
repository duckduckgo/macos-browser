//
//  FileStoreTests.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import XCTest
import CryptoKit
@testable import DuckDuckGo_Privacy_Browser

class FileStoreTests: XCTestCase {
    private let testFileName = "TestFile"
    private let testData = "Hello, World".data(using: .utf8)!

    override func setUp() {
        super.setUp()
        removeTestFiles()
    }

    override func tearDown() {
        super.tearDown()
        removeTestFiles()
    }

    func testStoringDataWithoutEncryption() {
        let store = FileStore()
        XCTAssertNoThrow(try store.persist(testData, fileName: testFileName))
    }

    func testReadingNonExistentData() {
        let store = FileStore()
        var data: Data?
        XCTAssertThrowsError(data = try store.loadData(named: testFileName), NSCocoaErrorDomain) {
            guard ($0 as? CocoaError)?.code == .fileReadNoSuchFile else {
                return XCTFail("Unexpected \($0), expected \(CocoaError(.fileReadNoSuchFile))")
            }
        }
        XCTAssertNil(data)
    }

    func testReadingDataWithoutEncryption() {
        let store = FileStore()

        XCTAssertNoThrow(try store.persist(testData, fileName: testFileName))
        var readData: Data!
        XCTAssertNoThrow(readData = try store.loadData(named: testFileName))

        XCTAssertEqual(testData, readData)
    }

    func testStoringAndRetrievingEncryptedData() {
        let keyStore = MockEncryptionKeyStore(generator: EncryptionKeyGenerator(), account: "mock-account")
        let key = try? keyStore.readKey()
        let encryptedStore = FileStore(encryptionKey: key!)

        XCTAssertNoThrow(try encryptedStore.persist(testData, fileName: testFileName))

        // A new key should have been generated in the key store.
        XCTAssertEqual(keyStore.storedKeys.count, 1)

        // Verify that there is data at the location that was written to.
        XCTAssertTrue(encryptedStore.hasData(for: testFileName))

        // Data should come back decrypted, so it should be equal to the original test data.
        var data: Data!
        XCTAssertNoThrow(try data = encryptedStore.loadData(named: testFileName))
        XCTAssertEqual(data, testData)
    }

    func testOverwritingStoredFiles() {
        let keyStore = MockEncryptionKeyStore(generator: EncryptionKeyGenerator(), account: "mock-account")
        let key = try? keyStore.readKey()
        let encryptedStore = FileStore(encryptionKey: key!)

        XCTAssertNoThrow(try encryptedStore.persist("First Write".data(using: .utf8)!, fileName: testFileName))
        XCTAssertNoThrow(try encryptedStore.persist("Second Write".data(using: .utf8)!, fileName: testFileName))
        XCTAssertNoThrow(try encryptedStore.persist("Third Write".data(using: .utf8)!, fileName: testFileName))

        var data: Data!
        XCTAssertNoThrow(data = try encryptedStore.loadData(named: testFileName))
        XCTAssertEqual("Third Write".data(using: .utf8), data)
    }

    func testRemovingStoredFiles() {
        let keyStore = MockEncryptionKeyStore(generator: EncryptionKeyGenerator(), account: "mock-account")
        let key = try? keyStore.readKey()
        let encryptedStore = FileStore(encryptionKey: key!)

        XCTAssertNoThrow(try encryptedStore.persist("First Write".data(using: .utf8)!, fileName: testFileName))
        XCTAssertNoThrow(try encryptedStore.persist("Second Write".data(using: .utf8)!, fileName: testFileName + "2"))
        XCTAssertNoThrow(try encryptedStore.persist("Third Write".data(using: .utf8)!, fileName: testFileName + "3"))

        encryptedStore.remove(testFileName + "2")

        XCTAssertNoThrow(try encryptedStore.loadData(named: testFileName))
        XCTAssertThrowsError(try encryptedStore.loadData(named: testFileName + "2"), NSCocoaErrorDomain) {
            guard ($0 as? CocoaError)?.code == .fileReadNoSuchFile else {
                return XCTFail("Unexpected \($0), expected \(CocoaError(.fileReadNoSuchFile))")
            }
        }
        XCTAssertNoThrow(try encryptedStore.loadData(named: testFileName + "3"))
    }

    func testRemovingNonExistentFile() {
        let store = FileStore()

        XCTAssertFalse(store.hasData(for: testFileName))
        XCTAssertNoThrow(store.remove(testFileName))
    }

    func testCheckingFilePresence() {
        let store = FileStore()

        let data = "Hello, World".data(using: .utf8)!
        XCTAssertFalse(store.hasData(for: testFileName))
        XCTAssertNoThrow(try store.persist(data, fileName: testFileName))
        XCTAssertTrue(store.hasData(for: testFileName))
    }

    func testPersistenceLocation() {
        let fileName = "TestFile"
        let location = FileStore().persistenceLocation(for: fileName)
        let components = location.pathComponents

        XCTAssertEqual(components.last!, fileName)
    }

    private func removeTestFiles() {
        try? FileManager.default.removeItem(at: FileStore().persistenceLocation(for: testFileName))
    }

}
