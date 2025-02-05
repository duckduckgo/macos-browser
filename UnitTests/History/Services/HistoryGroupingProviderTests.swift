//
//  HistoryGroupingProviderTests.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

import Common
import History
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class MockHistoryGroupingDataSource: HistoryGroupingDataSource {
    var history: BrowsingHistory? = []
}

final class HistoryGroupingProviderTests: XCTestCase {
    private var dataSource: MockHistoryGroupingDataSource!
    private var featureFlagger: MockFeatureFlagger!
    private var provider: HistoryGroupingProvider!

    override func setUp() async throws {
        dataSource = MockHistoryGroupingDataSource()
        featureFlagger = MockFeatureFlagger()
        provider = HistoryGroupingProvider(dataSource: dataSource, featureFlagger: featureFlagger)
    }

    // MARK: - getRecentVisits with deduplication

    func testWhenHistoryViewIsEnabledThenRecentVisitsAreDeduplicatedLeavingMostRecentVisit() throws {
        featureFlagger.isFeatureOn = true

        let date = Date.noonToday
        dataSource.history = [
            .make(url: "https://example.com".url!, visits: [
                Visit(date: date.addingTimeInterval(-1)),
                Visit(date: date.addingTimeInterval(-2)),
                Visit(date: date.addingTimeInterval(-3))
            ])
        ]

        let recentVisits = provider.getRecentVisits(maxCount: 100)
        let firstRecentVisit = try XCTUnwrap(recentVisits[safe: 0])
        XCTAssertEqual(recentVisits.count, 1)
        XCTAssertEqual(firstRecentVisit.date, date.addingTimeInterval(-1))
    }

    func testWhenHistoryViewIsEnabledThenRecentVisitsAreSortedByMostRecentVisit() throws {
        featureFlagger.isFeatureOn = true

        let date = Date.noonToday
        dataSource.history = [
            .make(url: "https://example.com".url!, visits: [
                Visit(date: date.addingTimeInterval(-3)),
                Visit(date: date.addingTimeInterval(-5)),
                Visit(date: date.addingTimeInterval(-10))
            ]),
            .make(url: "https://example.com/index2.html".url!, visits: [
                Visit(date: date.addingTimeInterval(-1)),
                Visit(date: date.addingTimeInterval(-20))
            ])
        ]

        let recentVisits = provider.getRecentVisits(maxCount: 100)
        let firstRecentVisit = try XCTUnwrap(recentVisits[safe: 0])
        let secondRecentVisit = try XCTUnwrap(recentVisits[safe: 1])
        XCTAssertEqual(recentVisits.count, 2)
        XCTAssertEqual(firstRecentVisit.date, date.addingTimeInterval(-1))
        XCTAssertEqual(secondRecentVisit.date, date.addingTimeInterval(-3))
    }

    func testWhenHistoryViewIsEnabledThenRecentVisitsAreLimitedToMaxCount() throws {
        featureFlagger.isFeatureOn = true

        let date = Date.noonToday
        dataSource.history = [
            .make(url: "https://example.com".url!, visits: [
                Visit(date: date.addingTimeInterval(-3)),
            ]),
            .make(url: "https://example.com/index2.html".url!, visits: [
                Visit(date: date.addingTimeInterval(-1)),
            ]),
            .make(url: "https://example.com/index3.html".url!, visits: [
                Visit(date: date.addingTimeInterval(-10)),
            ]),
            .make(url: "https://example.com/index4.html".url!, visits: [
                Visit(date: date.addingTimeInterval(-20)),
            ]),
            .make(url: "https://example.com/index5.html".url!, visits: [
                Visit(date: date.addingTimeInterval(-6)),
            ])
        ]

        let recentVisits = provider.getRecentVisits(maxCount: 3)
        XCTAssertEqual(recentVisits.count, 3)
        XCTAssertEqual(recentVisits.map(\.date), [
            date.addingTimeInterval(-1),
            date.addingTimeInterval(-3),
            date.addingTimeInterval(-6)
        ])
    }

    func testWhenHistoryViewIsEnabledThenRecentVisitsAreLimitedToCurrentDay() throws {
        featureFlagger.isFeatureOn = true

        let date = Date.noonToday
        dataSource.history = [
            .make(url: "https://example.com".url!, visits: [
                Visit(date: date.addingTimeInterval(-3)),
            ]),
            .make(url: "https://example.com/index2.html".url!, visits: [
                Visit(date: date.daysAgo(1)),
            ]),
            .make(url: "https://example.com/index3.html".url!, visits: [
                Visit(date: date.addingTimeInterval(-10)),
            ]),
            .make(url: "https://example.com/index4.html".url!, visits: [
                Visit(date: date.addingTimeInterval(-20*3600)),
            ]),
            .make(url: "https://example.com/index5.html".url!, visits: [
                Visit(date: date.addingTimeInterval(-6)),
            ])
        ]

        let recentVisits = provider.getRecentVisits(maxCount: 100)
        XCTAssertEqual(recentVisits.count, 3)
        XCTAssertEqual(recentVisits.map(\.date), [
            date.addingTimeInterval(-3),
            date.addingTimeInterval(-6),
            date.addingTimeInterval(-10)
        ])
    }

    // MARK: - getRecentVisits without deduplication

    func testWhenHistoryViewIsDisabledThenRecentVisitsAreNotDeduplicated() throws {
        featureFlagger.isFeatureOn = false

        let date = Date.noonToday
        dataSource.history = [
            .make(url: "https://example.com".url!, visits: [
                Visit(date: date.addingTimeInterval(-1)),
                Visit(date: date.addingTimeInterval(-2)),
                Visit(date: date.addingTimeInterval(-3))
            ])
        ]

        let recentVisits = provider.getRecentVisits(maxCount: 100)
        XCTAssertEqual(recentVisits.count, 3)
        XCTAssertEqual(recentVisits.map(\.date), [
            date.addingTimeInterval(-1),
            date.addingTimeInterval(-2),
            date.addingTimeInterval(-3)
        ])
    }

    func testWhenHistoryViewIsDisabledThenRecentVisitsAreSortedByMostRecentVisit() throws {
        featureFlagger.isFeatureOn = false

        let date = Date.noonToday
        dataSource.history = [
            .make(url: "https://example.com".url!, visits: [
                Visit(date: date.addingTimeInterval(-3)),
                Visit(date: date.addingTimeInterval(-5)),
                Visit(date: date.addingTimeInterval(-10))
            ]),
            .make(url: "https://example.com/index2.html".url!, visits: [
                Visit(date: date.addingTimeInterval(-1)),
                Visit(date: date.addingTimeInterval(-20))
            ])
        ]

        let recentVisits = provider.getRecentVisits(maxCount: 100)
        XCTAssertEqual(recentVisits.count, 5)
        XCTAssertEqual(recentVisits.map(\.historyEntry?.url), [
            "https://example.com/index2.html".url!,
            "https://example.com".url!,
            "https://example.com".url!,
            "https://example.com".url!,
            "https://example.com/index2.html".url!
        ])
        XCTAssertEqual(recentVisits.map(\.date), [
            date.addingTimeInterval(-1),
            date.addingTimeInterval(-3),
            date.addingTimeInterval(-5),
            date.addingTimeInterval(-10),
            date.addingTimeInterval(-20)
        ])
    }

    func testWhenHistoryViewIsDisabledThenRecentVisitsAreLimitedToMaxCount() throws {
        featureFlagger.isFeatureOn = false

        let date = Date.noonToday
        dataSource.history = [
            .make(url: "https://example.com".url!, visits: [
                Visit(date: date.addingTimeInterval(-3)),
                Visit(date: date.addingTimeInterval(-5)),
                Visit(date: date.addingTimeInterval(-10))
            ]),
            .make(url: "https://example.com/index2.html".url!, visits: [
                Visit(date: date.addingTimeInterval(-1)),
                Visit(date: date.addingTimeInterval(-20))
            ])
        ]

        let recentVisits = provider.getRecentVisits(maxCount: 3)
        XCTAssertEqual(recentVisits.count, 3)
        XCTAssertEqual(recentVisits.map(\.date), [
            date.addingTimeInterval(-1),
            date.addingTimeInterval(-3),
            date.addingTimeInterval(-5)
        ])
    }

    func testWhenHistoryViewIsDisabledThenRecentVisitsAreLimitedToCurrentDay() throws {
        featureFlagger.isFeatureOn = false

        let date = Date.noonToday
        dataSource.history = [
            .make(url: "https://example.com".url!, visits: [
                Visit(date: date.addingTimeInterval(-3)),
                Visit(date: date.addingTimeInterval(-5000)),
                Visit(date: date.addingTimeInterval(-20*3600))
            ]),
            .make(url: "https://example.com/index2.html".url!, visits: [
                Visit(date: date.addingTimeInterval(-3000)),
                Visit(date: date.daysAgo(1))
            ])
        ]

        let recentVisits = provider.getRecentVisits(maxCount: 100)
        XCTAssertEqual(recentVisits.count, 3)
        XCTAssertEqual(recentVisits.map(\.date), [
            date.addingTimeInterval(-3),
            date.addingTimeInterval(-3000),
            date.addingTimeInterval(-5000)
        ])
    }

    // MARK: - getVisitGroupings with deduplication

    func testWhenHistoryViewIsEnabledThenVisitGroupingsAreDeduplicated() throws {
        featureFlagger.isFeatureOn = true

        let date = Date.noonToday
        dataSource.history = [
            .make(url: "https://example.com".url!, visits: [
                Visit(date: date.addingTimeInterval(-3)),
                Visit(date: date.addingTimeInterval(-100)),
                Visit(date: date.daysAgo(1)),
                Visit(date: date.daysAgo(1).addingTimeInterval(-100)),
                Visit(date: date.daysAgo(2).addingTimeInterval(-1)),
                Visit(date: date.daysAgo(2).addingTimeInterval(-100)),
                Visit(date: date.daysAgo(4)),
                Visit(date: date.daysAgo(4).addingTimeInterval(-100)),
                Visit(date: date.daysAgo(5).addingTimeInterval(-1)),
                Visit(date: date.daysAgo(5).addingTimeInterval(-100))
            ]),
            .make(url: "https://example.com/index2.html".url!, visits: [
                Visit(date: date.addingTimeInterval(-3000)),
                Visit(date: date.addingTimeInterval(-5000)),
                Visit(date: date.daysAgo(1).addingTimeInterval(-1)),
                Visit(date: date.daysAgo(1).addingTimeInterval(-5000)),
                Visit(date: date.daysAgo(2)),
                Visit(date: date.daysAgo(2).addingTimeInterval(-5000)),
                Visit(date: date.daysAgo(3)),
                Visit(date: date.daysAgo(3).addingTimeInterval(-5000)),
                Visit(date: date.daysAgo(5)),
                Visit(date: date.daysAgo(5).addingTimeInterval(-5000))
            ])
        ]

        let groupings = provider.getVisitGroupings()

        XCTAssertEqual(groupings.count, 6)
        XCTAssertEqual(groupings.map { $0.visits.map(\.date) }, [
            [
                date.addingTimeInterval(-3),
                date.addingTimeInterval(-3000)
            ],
            [
                date.daysAgo(1),
                date.daysAgo(1).addingTimeInterval(-1)
            ],
            [
                date.daysAgo(2),
                date.daysAgo(2).addingTimeInterval(-1)
            ],
            [
                date.daysAgo(3)
            ],
            [
                date.daysAgo(4)
            ],
            [
                date.daysAgo(5),
                date.daysAgo(5).addingTimeInterval(-1)
            ]
        ])
        XCTAssertEqual(groupings.map { $0.visits.map(\.historyEntry?.url) }, [
            [
                "https://example.com".url!,
                "https://example.com/index2.html".url!
            ],
            [
                "https://example.com".url!,
                "https://example.com/index2.html".url!
            ],
            [
                "https://example.com/index2.html".url!,
                "https://example.com".url!
            ],
            [
                "https://example.com/index2.html".url!
            ],
            [
                "https://example.com".url!,
            ],
            [
                "https://example.com/index2.html".url!,
                "https://example.com".url!
            ]
        ])
    }

    // MARK: - getVisitGroupings without deduplication

    func testWhenHistoryViewIsDisabledThenVisitGroupingsAreNotDeduplicated() throws {
        featureFlagger.isFeatureOn = false

        let date = Date.noonToday
        dataSource.history = [
            .make(url: "https://example.com".url!, visits: [
                Visit(date: date.addingTimeInterval(-3)),
                Visit(date: date.addingTimeInterval(-100)),
                Visit(date: date.daysAgo(1)),
                Visit(date: date.daysAgo(1).addingTimeInterval(-100)),
                Visit(date: date.daysAgo(2).addingTimeInterval(-1)),
                Visit(date: date.daysAgo(2).addingTimeInterval(-100)),
                Visit(date: date.daysAgo(4)),
                Visit(date: date.daysAgo(4).addingTimeInterval(-100)),
                Visit(date: date.daysAgo(5).addingTimeInterval(-1)),
                Visit(date: date.daysAgo(5).addingTimeInterval(-100))
            ]),
            .make(url: "https://example.com/index2.html".url!, visits: [
                Visit(date: date.addingTimeInterval(-3000)),
                Visit(date: date.addingTimeInterval(-5000)),
                Visit(date: date.daysAgo(1).addingTimeInterval(-1)),
                Visit(date: date.daysAgo(1).addingTimeInterval(-5000)),
                Visit(date: date.daysAgo(2)),
                Visit(date: date.daysAgo(2).addingTimeInterval(-5000)),
                Visit(date: date.daysAgo(3)),
                Visit(date: date.daysAgo(3).addingTimeInterval(-5000)),
                Visit(date: date.daysAgo(5)),
                Visit(date: date.daysAgo(5).addingTimeInterval(-5000))
            ])
        ]

        let groupings = provider.getVisitGroupings()

        XCTAssertEqual(groupings.count, 6)
        XCTAssertEqual(groupings.map { $0.visits.map(\.date) }, [
            [
                date.addingTimeInterval(-3),
                date.addingTimeInterval(-100),
                date.addingTimeInterval(-3000),
                date.addingTimeInterval(-5000)
            ],
            [
                date.daysAgo(1),
                date.daysAgo(1).addingTimeInterval(-1),
                date.daysAgo(1).addingTimeInterval(-100),
                date.daysAgo(1).addingTimeInterval(-5000)
            ],
            [
                date.daysAgo(2),
                date.daysAgo(2).addingTimeInterval(-1),
                date.daysAgo(2).addingTimeInterval(-100),
                date.daysAgo(2).addingTimeInterval(-5000)
            ],
            [
                date.daysAgo(3),
                date.daysAgo(3).addingTimeInterval(-5000)
            ],
            [
                date.daysAgo(4),
                date.daysAgo(4).addingTimeInterval(-100)
            ],
            [
                date.daysAgo(5),
                date.daysAgo(5).addingTimeInterval(-1),
                date.daysAgo(5).addingTimeInterval(-100),
                date.daysAgo(5).addingTimeInterval(-5000)
            ]
        ])
        XCTAssertEqual(groupings.map { $0.visits.map(\.historyEntry?.url) }, [
            [
                "https://example.com".url!,
                "https://example.com".url!,
                "https://example.com/index2.html".url!,
                "https://example.com/index2.html".url!
            ],
            [
                "https://example.com".url!,
                "https://example.com/index2.html".url!,
                "https://example.com".url!,
                "https://example.com/index2.html".url!
            ],
            [
                "https://example.com/index2.html".url!,
                "https://example.com".url!,
                "https://example.com".url!,
                "https://example.com/index2.html".url!
            ],
            [
                "https://example.com/index2.html".url!,
                "https://example.com/index2.html".url!
            ],
            [
                "https://example.com".url!,
                "https://example.com".url!
            ],
            [
                "https://example.com/index2.html".url!,
                "https://example.com".url!,
                "https://example.com".url!,
                "https://example.com/index2.html".url!
            ]
        ])
    }
}

private extension Date {
    /// Useful for date calculations to ensure we're not going into a previous day
    /// when removing a small time interval.
    static var noonToday: Date {
        Date.startOfDayTomorrow.addingTimeInterval(-12*3600)
    }
}

private extension HistoryEntry {
    static func make(
        identifier: UUID = UUID(),
        url: URL,
        title: String? = nil,
        failedToLoad: Bool = false,
        numberOfTotalVisits: Int = 1,
        lastVisit: Date = Date(),
        visits: Set<Visit>,
        numberOfTrackersBlocked: Int = 0,
        blockedTrackingEntities: Set<String> = [],
        trackersFound: Bool = false
    ) -> HistoryEntry {
        let entry = HistoryEntry(
            identifier: identifier,
            url: url,
            title: title,
            failedToLoad: failedToLoad,
            numberOfTotalVisits: numberOfTotalVisits,
            lastVisit: lastVisit,
            visits: [],
            numberOfTrackersBlocked: numberOfTrackersBlocked,
            blockedTrackingEntities: blockedTrackingEntities,
            trackersFound: trackersFound
        )
        entry.visits = Set(visits.map {
            Visit(date: $0.date, identifier: entry.url, historyEntry: entry)
        })
        return entry
    }
}
