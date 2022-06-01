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

final class FileStoreTests: XCTestCase {
    private let testFileName = "TestFile"
    private lazy var testFileLocation = URL.persistenceLocation(for: testFileName)
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
        let store = EncryptedFileStore()
        let success = store.persist(testData, url: testFileLocation)

        XCTAssertTrue(success)
    }

    func testReadingNonExistentData() {
        let store = EncryptedFileStore()
        let data = store.loadData(at: testFileLocation)

        XCTAssertNil(data)
    }

    func testReadingDataWithoutEncryption() {
        let store = EncryptedFileStore()

        _ = store.persist(testData, url: testFileLocation)
        let readData = store.loadData(at: testFileLocation)

        XCTAssertEqual(testData, readData)
    }

    func testStoringAndRetrievingEncryptedData() {
        let keyStore = MockEncryptionKeyStore(generator: EncryptionKeyGenerator(), account: "mock-account")
        let key = try? keyStore.readKey()
        let encryptedStore = EncryptedFileStore(encryptionKey: key!)

        XCTAssertTrue(encryptedStore.persist(testData, url: testFileLocation))

        // A new key should have been generated in the key store.
        XCTAssertEqual(keyStore.storedKeys.count, 1)

        // Verify that there is data at the location that was written to.
        XCTAssertTrue(encryptedStore.hasData(at: testFileLocation))

        // Data should come back decrypted, so it should be equal to the original test data.
        let data = encryptedStore.loadData(at: testFileLocation)
        XCTAssertEqual(data, testData)
    }

    func testThatLoadDataFromEncryptedStoreDecryptsByDefault() throws {
        let keyStore = MockEncryptionKeyStore(generator: EncryptionKeyGenerator(), account: "mock-account")
        let key = try? keyStore.readKey()
        let encryptedStore = EncryptedFileStore(encryptionKey: key!)

        _ = encryptedStore.persist(testData, url: testFileLocation)
        let readData = try XCTUnwrap(encryptedStore.loadData(at: testFileLocation))

        XCTAssertEqual(testData, readData)
    }

    func testWhenLoadDataIsCalledWithoutDecryptionThenDataIsNotDecrypted() throws {
        let keyStore = MockEncryptionKeyStore(generator: EncryptionKeyGenerator(), account: "mock-account")
        let key = try? keyStore.readKey()
        let encryptedStore = EncryptedFileStore(encryptionKey: key!)

        _ = encryptedStore.persist(testData, url: testFileLocation)
        let readData = try XCTUnwrap(encryptedStore.loadData(at: testFileLocation, decryptIfNeeded: false))

        XCTAssertNotEqual(testData, readData)
        XCTAssertEqual(encryptedStore.decrypt(readData), testData)
    }

    func testOverwritingStoredFiles() {
        let keyStore = MockEncryptionKeyStore(generator: EncryptionKeyGenerator(), account: "mock-account")
        let key = try? keyStore.readKey()
        let encryptedStore = EncryptedFileStore(encryptionKey: key!)

        XCTAssertTrue(encryptedStore.persist("First Write".data(using: .utf8)!, url: testFileLocation))
        XCTAssertTrue(encryptedStore.persist("Second Write".data(using: .utf8)!, url: testFileLocation))
        XCTAssertTrue(encryptedStore.persist("Third Write".data(using: .utf8)!, url: testFileLocation))

        let data = encryptedStore.loadData(at: testFileLocation)
        XCTAssertEqual("Third Write".data(using: .utf8), data)
    }

    func testCheckingFilePresence() {
        let store = EncryptedFileStore()

        let data = "Hello, World".data(using: .utf8)!
        XCTAssertTrue(store.persist(data, url: testFileLocation))
        XCTAssertTrue(store.hasData(at: testFileLocation))
    }

    func testPersistenceLocation() {
        let fileName = "TestFile"
        let location = URL.persistenceLocation(for: fileName)
        let components = location.pathComponents

        XCTAssertEqual(components.last!, fileName)
    }

    private func removeTestFiles() {
        try? FileManager.default.removeItem(at: URL.persistenceLocation(for: testFileName))
    }

}
