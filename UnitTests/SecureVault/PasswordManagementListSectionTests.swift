//
//  PasswordManagementListSectionTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
@testable import BrowserServicesKit
@testable import DuckDuckGo_Privacy_Browser

final class PasswordManagementListSectionTests: XCTestCase {

    private lazy var accounts = [
        login(named: "Alfa"),
        login(named: "Alfa Two"),
        login(named: "Bravo"),
        login(named: "Charlie"),
        login(named: "Yankee"),
        login(named: "Zulu"),
        login(named: "Zulu Two")
    ]

    private lazy var nonASCIIAccounts = [
        login(named: "a"),
        login(named: "b"),
        login(named: "c"),
        login(named: "s"),
        login(named: "ą"),
        login(named: "ć"),
        login(named: "ś"),
        login(named: "š")
    ]

    func testWhenSortingEmptyArray_ThenNoSectionsAreReturned() {
        let sections = PasswordManagementListSection.sections(with: [], by: \.id, order: .ascending)
        XCTAssertTrue(sections.isEmpty)
    }

    func testWhenSortingItemsByTitle_AndOrderIsAscending_ThenSectionsAreAlphabetical() {
        let sections = PasswordManagementListSection.sections(with: accounts, by: \.firstCharacter, order: .ascending)
        XCTAssertEqual(sections.count, 5)
        XCTAssertEqual(sections.map(\.title), ["A", "B", "C", "Y", "Z"])

        XCTAssertEqual(sections.first!.items.map(\.title), ["Alfa", "Alfa Two"])
        XCTAssertEqual(sections.last!.items.map(\.title), ["Zulu", "Zulu Two"])
    }

    func testWhenSortingItemsByTitle_AndItemsAreNonASCII_ThenSectionsAreSortedUsingLocalizedComparison() {
        let sections = PasswordManagementListSection.sections(with: nonASCIIAccounts, by: \.firstCharacter, order: .ascending)
        XCTAssertEqual(sections.count, 8)
        XCTAssertEqual(sections.map(\.title), ["A", "Ą", "B", "C", "Ć", "S", "Ś", "Š"])
    }

    func testWhenSortingItemsByTitle_AndOrderIsDescending_ThenSectionsAreReverseAlphabetical() {
        let sections = PasswordManagementListSection.sections(with: accounts, by: \.firstCharacter, order: .descending)
        XCTAssertEqual(sections.count, 5)
        XCTAssertEqual(sections.map(\.title), ["Z", "Y", "C", "B", "A"])

        XCTAssertEqual(sections.first!.items.map(\.title), ["Zulu Two", "Zulu"])
        XCTAssertEqual(sections.last!.items.map(\.title), ["Alfa Two", "Alfa"])
    }

    func testWhenSortingItemsByTitle_AndTitlesUseDigits_ThenOctothorpeTitleIsUsed() {
        let accounts = [
            login(named: "123"),
            login(named: "😬"),
            login(named: "...")
        ]

        let sections = PasswordManagementListSection.sections(with: accounts, by: \.firstCharacter, order: .ascending)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first!.title, "#")
    }

    private let enFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en-US")
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()
    private let currentLocaleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()
    func testWhenSortingItemsByDate_AndAllMonthsAndYearsAreTheSame_ThenOneSectionIsReturned() {
        let months = [1, 1, 1, 1, 1]
        let accounts = months.map { login(named: "Login", month: $0, year: 2000) }
        let sections = PasswordManagementListSection.sections(with: accounts, by: \.created, order: .ascending)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first!.items.count, months.count)
        XCTAssertEqual(sections.first!.title, currentLocaleFormatter.string(from: enFormatter.date(from: "Jan 2000")!))
    }

    func testWhenSortingItemsByDate_AndMonthsAreDifferent_ThenMultipleSectionsAreReturned() {
        let months = 1...12
        let accounts = months.map { login(named: "Login", month: $0) }
        let sections = PasswordManagementListSection.sections(with: accounts, by: \.created, order: .ascending)

        XCTAssertEqual(sections.count, 12)

        for section in sections {
            XCTAssertEqual(section.items.count, 1)
        }
    }

    func testWhenSortingItemsByDate_AndMonthsAreDifferent_AndThereAreMultipleYears_ThenMultipleSectionsAreReturnedSortedAscending() {
        let months = 1...12
        let firstYearAccounts = months.map { login(named: "Login", month: $0, year: 2000) }
        let secondYearAccounts = months.map { login(named: "Login", month: $0, year: 2001) }
        let allAccounts = firstYearAccounts + secondYearAccounts
        let sections = PasswordManagementListSection.sections(with: allAccounts, by: \.created, order: .ascending)

        XCTAssertEqual(sections.count, 24)

        for section in sections {
            XCTAssertEqual(section.items.count, 1)
        }

        let expectedTitles = ["Dec 2001", "Nov 2001", "Oct 2001", "Sep 2001", "Aug 2001", "Jul 2001", "Jun 2001", "May 2001", "Apr 2001", "Mar 2001", "Feb 2001", "Jan 2001", "Dec 2000", "Nov 2000", "Oct 2000", "Sep 2000", "Aug 2000", "Jul 2000", "Jun 2000", "May 2000", "Apr 2000", "Mar 2000", "Feb 2000", "Jan 2000"].map {
            currentLocaleFormatter.string(from: enFormatter.date(from: $0)!)
        }
        let actualTitles = sections.map(\.title)
        XCTAssertEqual(actualTitles, expectedTitles)
    }

    private func login(named name: String, month: Int = 1, year: Int = 2000) -> SecureVaultItem {
        let calendar = Calendar.current
        let components = DateComponents(calendar: calendar, year: year, month: month, day: 1)
        let date = calendar.date(from: components) ?? Date()

        let account = SecureVaultModels.WebsiteAccount(id: "1",
                                                       title: name,
                                                       username: "Username",
                                                       domain: "\(name).com",
                                                       created: date,
                                                       lastUpdated: date)

        return SecureVaultItem.account(account)
    }

}
