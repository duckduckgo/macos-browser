//
//  DataBrokerProtectionKeyStoreProviderTests.swift
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

import XCTest
import SecureStorage
@testable import DataBrokerProtection

final class DataBrokerProtectionKeyStoreProviderTests: XCTestCase {

    private let mockGroupNameProvider = MockGroupNameProvider()

    func testWhenReadData_newAttributesAreUsedFirst_andNoFallbackQueryIsPerformedIfDataFound() throws {

        try DataBrokerProtectionKeyStoreProvider.EntryName.allCases.forEach { entry in
            // Given
            let mockKeychainService = MockDBPKeychainService()
            mockKeychainService.mode = .migratedDataFound
            let sut = DataBrokerProtectionKeyStoreProvider(keychainService: mockKeychainService, groupNameProvider: mockGroupNameProvider)

            // When
            _ = try sut.readData(named: entry.rawValue, serviceName: sut.keychainServiceName)

            // Then
            let secAttrAccessibleQueryValue = mockKeychainService.latestItemMatchingQuery[kSecAttrAccessible as String]! as? String

            XCTAssertEqual(secAttrAccessibleQueryValue, kSecAttrAccessibleAfterFirstUnlock as String)
            XCTAssert(mockKeychainService.itemMatchingCallCount == 1)
        }
    }

    func testWhenReadData_andNoDataFoundWithNewAttributes_thenFallbackQueryIsPerformedWithLegacyAttributes_andUpdateIsPerformed() throws {

        try DataBrokerProtectionKeyStoreProvider.EntryName.allCases.forEach { entry in
            // Given
            let mockKeychainService = MockDBPKeychainService()
            mockKeychainService.mode = .legacyDataFound
            let sut = DataBrokerProtectionKeyStoreProvider(keychainService: mockKeychainService, groupNameProvider: mockGroupNameProvider)

            // When
            _ = try sut.readData(named: entry.rawValue, serviceName: sut.keychainServiceName)

            // Then
            let secAttrAccessibleQueryValue = mockKeychainService.latestItemMatchingQuery[kSecAttrAccessible as String]! as? String
            let secAttrAccessiblUpdateValue = mockKeychainService.latestUpdateAttributes[kSecAttrAccessible as String]! as? String

            XCTAssertEqual(secAttrAccessibleQueryValue, kSecAttrAccessibleWhenUnlocked as String)
            XCTAssertEqual(secAttrAccessiblUpdateValue, kSecAttrAccessibleAfterFirstUnlock as String)
            XCTAssert(mockKeychainService.itemMatchingCallCount == 2)
            XCTAssert(mockKeychainService.updateCallCount == 1)
        }
    }

    func testWhenReadData_andNoValueIsFound_thenTwoQueriesArePerformed_noUpdateIsAttempted_andNilIsReturned() throws {

        try DataBrokerProtectionKeyStoreProvider.EntryName.allCases.forEach { entry in
            // Given
            let mockKeychainService = MockDBPKeychainService()
            mockKeychainService.mode = .nothingFound
            let sut = DataBrokerProtectionKeyStoreProvider(keychainService: mockKeychainService, groupNameProvider: mockGroupNameProvider)

            // When
            let result = try sut.readData(named: entry.rawValue, serviceName: sut.keychainServiceName)

            // Then
            let secAttrAccessibleQueryValue = mockKeychainService.latestItemMatchingQuery[kSecAttrAccessible as String]! as? String

            XCTAssertEqual(secAttrAccessibleQueryValue, kSecAttrAccessibleWhenUnlocked as String)
            XCTAssert(mockKeychainService.itemMatchingCallCount == 2)
            XCTAssert(mockKeychainService.updateCallCount == 0)
            XCTAssertNil(result)
        }
    }

    func testWhenWriteData_correctKeychainAccessibilityValueIsUsed() throws {

        try DataBrokerProtectionKeyStoreProvider.EntryName.allCases.forEach { entry in
            // Given
            let originalString = "Mock Keychain data!"
            let data = originalString.data(using: .utf8)!
            let encodedString = data.base64EncodedString()
            let mockData = encodedString.data(using: .utf8)!
            let mockKeychainService = MockDBPKeychainService()
            let sut = DataBrokerProtectionKeyStoreProvider(keychainService: mockKeychainService, groupNameProvider: mockGroupNameProvider)

            // When
            _ = try sut.writeData(mockData, named: entry.rawValue, serviceName: sut.keychainServiceName)

            // Then
            XCTAssertEqual(mockKeychainService.addCallCount, 1)
            XCTAssertEqual(mockKeychainService.latestAddQuery[kSecAttrAccessible as String] as! String, kSecAttrAccessibleAfterFirstUnlock as String)
        }
    }

    func testWhenKeychainReadErrors_thenKeyStoreReadErrorIsThrown() throws {

        try DataBrokerProtectionKeyStoreProvider.EntryName.allCases.forEach { entry in
            // Given
            let mockKeychainService = MockDBPKeychainService()
            mockKeychainService.mode = .readError
            let expectedError = SecureStorageError.keystoreReadError(status: mockKeychainService.mode.statusCode!)
            let sut = DataBrokerProtectionKeyStoreProvider(keychainService: mockKeychainService, groupNameProvider: mockGroupNameProvider)

            // When
            XCTAssertThrowsError(try sut.readData(named: entry.rawValue, serviceName: sut.keychainServiceName)) { error in

                // Then
                XCTAssertEqual((error as! SecureStorageError), expectedError)
            }
        }
    }

    func testWhenKeychainUpdateErrors_thenKeyStoreUpdateErrorIsThrown() throws {

        try DataBrokerProtectionKeyStoreProvider.EntryName.allCases.forEach { entry in
            // Given
            let mockKeychainService = MockDBPKeychainService()
            mockKeychainService.mode = .updateError
            let expectedError = SecureStorageError.keystoreUpdateError(status: mockKeychainService.mode.statusCode!)
            let sut = DataBrokerProtectionKeyStoreProvider(keychainService: mockKeychainService, groupNameProvider: mockGroupNameProvider)

            // When
            XCTAssertThrowsError(try sut.readData(named: entry.rawValue, serviceName: sut.keychainServiceName)) { error in

                // Then
                XCTAssertEqual((error as! SecureStorageError), expectedError)
            }
        }
    }
}
