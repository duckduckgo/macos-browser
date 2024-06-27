//
//  BrokerJobDataProcessorTests.swift
//  
//
//  Created by Pete Smith on 27/06/2024.
//

import XCTest
@testable import DataBrokerProtection

final class BrokerJobDataProcessorTests: XCTestCase {

    private var sut: BrokerJobDataProcessor!

    override func setUpWithError() throws {
        sut = DefaultBrokerJobDataProcessor()
    }

    func testWhenScanDataIsFiltered_thenDeprecatedProfileQueriesAreIgnored() throws {

        // Given
        let profileQueries = BrokerProfileQueryData.mockQueries(withId: 2,
                                                                validProfileCountAndId: 3,
                                                                deprecatedProfileCountAndId: 5)

        // When
        let result = sut.filteredAndSortedJobData(forQueryData: profileQueries,
                                                  operationType: .scan, priorityDate: nil)

        // Then
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(((result as! [ScanJobData]).filter { $0.profileQueryId == 5 }).isEmpty)
    }

    func testWhenOptoutDataIsFiltered_thenDeprecatedProfileQueriesAreNotIgnored() throws {

        // Given
        let profileQueries = BrokerProfileQueryData.mockQueries(withId: 2,
                                                                validProfileCountAndId: 3,
                                                                deprecatedProfileCountAndId: 5)

        // When
        let result = sut.filteredAndSortedJobData(forQueryData: profileQueries,
                                                  operationType: .optOut, priorityDate: nil)

        // Then
        XCTAssertEqual(result.count, 8)
        XCTAssertTrue(((result as! [OptOutJobData]).filter { $0.profileQueryId == 5 }).count == 5)
    }

    func testWhenAllDataIsFiltered_thenDeprecatedProfileQueriesAreNotIgnored() throws {

        // Given
        let profileQueries = BrokerProfileQueryData.mockQueries(withId: 2,
                                                                validProfileCountAndId: 3,
                                                                deprecatedProfileCountAndId: 5)

        // When
        let result = sut.filteredAndSortedJobData(forQueryData: profileQueries,
                                                  operationType: .all, priorityDate: nil)

        // Then
        XCTAssertEqual(result.count, 16)
        let scanJobs = result.compactMap({ $0 as? ScanJobData })
        let optOutJobs = result.compactMap({ $0 as? OptOutJobData })
        XCTAssertEqual(scanJobs.count, 8)
        XCTAssertEqual(optOutJobs.count, 8)
    }
}
