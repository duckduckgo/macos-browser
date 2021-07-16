//
//  TrackerInfoViewModel.swift
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

struct TrackerInfoViewModel {

    struct Section {
        let name: String
        let rows: [Row]

        func adding(_ row: Row) -> Section {
            guard self.rows.filter({ $0.name == row.name }).count == 0 else { return self }
            var rows = self.rows
            rows.append(row)
            return Section(name: name, rows: rows.sorted(by: { $0.name < $1.name }))
        }
    }

    struct Row {
        let name: String
        let value: String
    }

    init(trackerInfo: TrackerInfo, isProtectionOn: Bool) {
        self.trackerInfo = trackerInfo

        let trackers = isProtectionOn ? trackerInfo.trackersBlocked : trackerInfo.trackersDetected
        sections = makeSections(from: Array(trackers))
    }

    private(set) var trackerInfo: TrackerInfo

    private(set) var sections = [Section]()

    private func makeSections(from trackers: [DetectedTracker]) -> [Section] {
        var sections = [Section]()

        let sortedTrackers = trackers.sorted(by: compareTrackersByHostName).sorted(by: compareTrackersByPrevalence)
        for tracker in sortedTrackers {
            guard let domain = tracker.domain else { continue }
            let networkName = tracker.networkNameForDisplay

            let row = Row(name: domain.drop(prefix: "www."),
                          value: tracker.knownTracker?.category ?? "")

            if let sectionIndex = sections.firstIndex(where: { $0.name == networkName }) {
                if row.name != networkName {
                    let section = sections[sectionIndex]
                    sections[sectionIndex] = section.adding(row)
                }
            } else {
                let rows: [Row] = (row.name == networkName) ? [] : [row]
                sections.append(Section(name: networkName, rows: rows))
            }
        }

        return sections
    }

    func compareTrackersByPrevalence(tracker1: DetectedTracker, tracker2: DetectedTracker) -> Bool {
        return tracker1.entity?.prevalence ?? 0 > tracker2.entity?.prevalence ?? 0
    }

    func compareTrackersByHostName(tracker1: DetectedTracker, tracker2: DetectedTracker) -> Bool {
        return tracker1.domain ?? "" < tracker2.domain ?? ""
    }

}

extension TrackerInfoViewModel {

    init?(trackerInfo: TrackerInfo?, isProtectionOn: Bool) {
        guard let trackerInfo = trackerInfo else {
            return nil
        }
        self.init(trackerInfo: trackerInfo, isProtectionOn: isProtectionOn)
    }

}
