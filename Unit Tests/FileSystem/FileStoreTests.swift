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
        let success = store.persist(testData, fileName: testFileName)

        XCTAssertTrue(success)
    }

    func testReadingNonExistentData() {
        let store = FileStore()
        let data = store.loadData(named: testFileName)

        XCTAssertNil(data)
    }

    func testReadingDataWithoutEncryption() {
        let store = FileStore()

        _ = store.persist(testData, fileName: testFileName)
        let readData = store.loadData(named: testFileName)

        XCTAssertEqual(testData, readData)
    }

    func testStoringAndRetrievingEncryptedData() {
        let keyStore = MockEncryptionKeyStore(generator: EncryptionKeyGenerator(), account: "mock-account")
        let key = try? keyStore.readKey()
        let encryptedStore = FileStore(encryptionKey: key!)

        XCTAssertTrue(encryptedStore.persist(testData, fileName: testFileName))

        // A new key should have been generated in the key store.
        XCTAssertEqual(keyStore.storedKeys.count, 1)

        // Verify that there is data at the location that was written to.
        XCTAssertTrue(encryptedStore.hasData(for: testFileName))

        // Data should come back decrypted, so it should be equal to the original test data.
        let data = encryptedStore.loadData(named: testFileName)
        XCTAssertEqual(data, testData)
    }

    func testOverwritingStoredFiles() {
        let keyStore = MockEncryptionKeyStore(generator: EncryptionKeyGenerator(), account: "mock-account")
        let key = try? keyStore.readKey()
        let encryptedStore = FileStore(encryptionKey: key!)

        XCTAssertTrue(encryptedStore.persist("First Write".data(using: .utf8)!, fileName: testFileName))
        XCTAssertTrue(encryptedStore.persist("Second Write".data(using: .utf8)!, fileName: testFileName))
        XCTAssertTrue(encryptedStore.persist("Third Write".data(using: .utf8)!, fileName: testFileName))

        let data = encryptedStore.loadData(named: testFileName)
        XCTAssertEqual("Third Write".data(using: .utf8), data)
    }

    func testCheckingFilePresence() {
        let store = FileStore()

        let data = "Hello, World".data(using: .utf8)!
        XCTAssertTrue(store.persist(data, fileName: testFileName))
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
