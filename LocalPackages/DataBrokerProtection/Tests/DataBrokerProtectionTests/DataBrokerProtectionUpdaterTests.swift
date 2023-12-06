//
//  DataBrokerProtectionUpdaterTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Foundation
import SecureStorage
@testable import DataBrokerProtection

final class DataBrokerProtectionUpdaterTests: XCTestCase {

    let repository = BrokerUpdaterRepositoryMock()
    let resources = ResourcesRepositoryMock()
    let vault: DataBrokerProtectionSecureVaultMock? = try? DataBrokerProtectionSecureVaultMock(providers:
                                                        SecureStorageProviders(
                                                            crypto: EmptySecureStorageCryptoProviderMock(),
                                                            database: SecureStorageDatabaseProviderMock(),
                                                            keystore: EmptySecureStorageKeyStoreProviderMock()))

    override func tearDown() {
        repository.reset()
        resources.reset()
        vault?.reset()
    }

    func testWhen24HoursDidntPassSinceLastRunDate_thenCheckingUpdatesIsSkipped() {
        if let vault = self.vault {
            let sut = DataBrokerProtectionBrokerUpdater(repository: repository, resources: resources, vault: vault)
            repository.lastRunDate = substract(hours: 10, to: Date())

            sut.checkForUpdatesInBrokerJSONFiles()

            XCTAssertFalse(repository.wasSaveLastRunDateCalled)
            XCTAssertFalse(resources.wasFetchBrokerFromResourcesFilesCalled)
        } else {
            XCTFail("Mock vault issue")
        }
    }

    func testWhen24PassedSinceLastRunDate_thenWeTryToUpdateBrokers() {
        if let vault = self.vault {
            let sut = DataBrokerProtectionBrokerUpdater(repository: repository, resources: resources, vault: vault)
            repository.lastRunDate = substract(hours: 25, to: Date())
            resources.brokersList = [.init(id: 1, name: "Broker", steps: [Step](), version: "1.0.1", schedulingConfig: .mock)]

            sut.checkForUpdatesInBrokerJSONFiles()

            XCTAssertTrue(repository.wasSaveLastRunDateCalled)
            XCTAssertTrue(resources.wasFetchBrokerFromResourcesFilesCalled)
        } else {
            XCTFail("Mock vault issue")
        }
    }

    func testWhenLastRunDateIsNil_thenWeTryToUpdateBrokers() {
        if let vault = self.vault {
            let sut = DataBrokerProtectionBrokerUpdater(repository: repository, resources: resources, vault: vault)
            repository.lastRunDate = nil
            resources.brokersList = [.init(id: 1, name: "Broker", steps: [Step](), version: "1.0.1", schedulingConfig: .mock)]

            sut.checkForUpdatesInBrokerJSONFiles()

            XCTAssertTrue(repository.wasSaveLastRunDateCalled)
            XCTAssertTrue(resources.wasFetchBrokerFromResourcesFilesCalled)
        } else {
            XCTFail("Mock vault issue")
        }
    }

    func testWhenSavedBrokerIsOnAnOldVersion_thenWeUpdateIt() {
        if let vault = self.vault {
            let sut = DataBrokerProtectionBrokerUpdater(repository: repository, resources: resources, vault: vault)
            repository.lastRunDate = nil
            resources.brokersList = [.init(id: 1, name: "Broker", steps: [Step](), version: "1.0.1", schedulingConfig: .mock)]
            vault.shouldReturnOldVersionBroker = true

            sut.checkForUpdatesInBrokerJSONFiles()

            XCTAssertTrue(repository.wasSaveLastRunDateCalled)
            XCTAssertTrue(resources.wasFetchBrokerFromResourcesFilesCalled)
            XCTAssertTrue(vault.wasBrokerUpdateCalled)
            XCTAssertFalse(vault.wasBrokerSavedCalled)
        } else {
            XCTFail("Mock vault issue")
        }
    }

    func testWhenSavedBrokerIsOnTheCurrentVersion_thenWeDoNotUpdateIt() {
        if let vault = self.vault {
            let sut = DataBrokerProtectionBrokerUpdater(repository: repository, resources: resources, vault: vault)
            repository.lastRunDate = nil
            resources.brokersList = [.init(id: 1, name: "Broker", steps: [Step](), version: "1.0.1", schedulingConfig: .mock)]
            vault.shouldReturnNewVersionBroker = true

            sut.checkForUpdatesInBrokerJSONFiles()

            XCTAssertTrue(repository.wasSaveLastRunDateCalled)
            XCTAssertTrue(resources.wasFetchBrokerFromResourcesFilesCalled)
            XCTAssertFalse(vault.wasBrokerUpdateCalled)
        } else {
            XCTFail("Mock vault issue")
        }
    }

    func testWhenFileBrokerIsNotStored_thenWeAddTheBrokerAndScanOperations() {
        if let vault = self.vault {
            let sut = DataBrokerProtectionBrokerUpdater(repository: repository, resources: resources, vault: vault)
            repository.lastRunDate = nil
            resources.brokersList = [.init(id: 1, name: "Broker", steps: [Step](), version: "1.0.0", schedulingConfig: .mock)]
            vault.profileQueries = [.mock]

            sut.checkForUpdatesInBrokerJSONFiles()

            XCTAssertTrue(repository.wasSaveLastRunDateCalled)
            XCTAssertTrue(resources.wasFetchBrokerFromResourcesFilesCalled)
            XCTAssertFalse(vault.wasBrokerUpdateCalled)
            XCTAssertTrue(vault.wasBrokerSavedCalled)
            XCTAssertTrue(areDatesEqualIgnoringSeconds(
                date1: Date(),
                date2: vault.lastPreferredRunDateOnScan)
            )
        } else {
            XCTFail("Mock vault issue")
        }
    }

    private func substract(hours: Int, to date: Date) -> Date {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.hour = -hours

        if let modifiedDate = calendar.date(byAdding: dateComponents, to: date) {
            return modifiedDate
        } else {
            fatalError("There was an issue changing the date hours.")
        }
    }

}
