//
//  CleanThisHistoryMenuItem.swift
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

import AppKit
import BrowserServicesKit
import Foundation
import History

final class ClearThisHistoryMenuItem: NSMenuItem {

    enum HistoryTimeWindow {
        case today
        case other(dateString: String)

        var isToday: Bool {
            switch self {
            case .today:
                return true
            case .other:
                return false
            }
        }

        var dateString: String? {
            switch self {
            case .today:
                return nil
            case .other(let dateString):
                return dateString
            }
        }

        init(dateString: String?) {
            if let dateString {
                self = .other(dateString: dateString)
            } else {
                self = .today
            }
        }
    }

    // Keep the dateString for alerts so we don't need to use the formatter again
    func setRepresentingObject(historyTimeWindow: HistoryTimeWindow) {
        representedObject = historyTimeWindow
    }

    var dateString: String? {
        (representedObject as? HistoryTimeWindow)?.dateString
    }

    var isToday: Bool {
        (representedObject as? HistoryTimeWindow)?.isToday ?? false
    }

    // Getting visits for the whole menu section in order to perform burning
    func getVisits(featureFlagger: FeatureFlagger) -> [Visit] {
        let visits = menu?.items.compactMap({ menuItem in
            return (menuItem as? VisitMenuItem)?.visit
        }) ?? []

        guard featureFlagger.isFeatureOn(.historyView) else {
            // historyView feature flag enables history items deduplication
            // where menu items don't represent all visits on a given day.
            // If disabled, we're free to just return visits represented by
            // menu items.
            return visits
        }

        // If historyView flag is enabled, we have to find all visits from a given day,
        // by querying their respective history entries.
        let allVisitsForGivenDay = visits.flatMap { visit in
            let date = visit.date
            return visit.historyEntry?.visits.filter { $0.date.isSameDay(date) } ?? []
        }
        return allVisitsForGivenDay
    }

}
