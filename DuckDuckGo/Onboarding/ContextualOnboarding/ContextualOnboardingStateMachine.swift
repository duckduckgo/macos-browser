//
//  ContextualOnboardingStateMachine.swift
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

import Foundation

protocol ContextualOnboardingDialogTypeProviding {
    func dialogTypeForTab(_ tab: Tab) -> ContextualDialogType?
}

protocol ContextualOnboardingStateUpdater {
    func gotItPressed()
}

enum ContextualDialogType: Equatable {
    case tryASearch
    case searchDone(shouldFollowUp: Bool)
    case tryASite
    case trackers(message: NSAttributedString, shouldFollowUp: Bool)
    case tryFireButton
    case highFive
}

final class ContextualOnboardingStateMachine: ContextualOnboardingDialogTypeProviding, ContextualOnboardingStateUpdater {
    let trackerMessageProvider: TrackerMessageProviding
    var state: ContextualOnboardingState = .notStarted
    var lastVisitTab: Tab?
    var lastVisitSite: URL?

    private init(trackerMessageProvider: TrackerMessageProviding = TrackerMessageProvider()) {
        self.trackerMessageProvider = trackerMessageProvider
    }

    static let shared = ContextualOnboardingStateMachine()

    func dialogTypeForTab(_ tab: Tab) -> ContextualDialogType? {
        guard case .url = tab.content else {
            return nil
        }
        reviewActionFor(tab: tab)
        switch state {
        case .notStarted:
            return nil
        case .initialOnboardingFinished:
            return .tryASearch
        case .searchDone:
            return .searchDone(shouldFollowUp: true)
        case .siteVisited:
            return .trackers(message: NSMutableAttributedString(string: "Some trackers"), shouldFollowUp: true)
        case .searchDoneSeen:
            return .tryASite
        case .searchDoneSiteDone:
            return .trackers(message: NSMutableAttributedString(string: "Some trackers"), shouldFollowUp: true)
        case .siteVisitedMajorTrackerSeen:
            return nil
        case .siteVisitedTrackersSeen:
            return nil
        case .siteVisitedFireDone:
            return .highFive
        case .searchDoneSeenTrySiteSeen:
            return nil
        case .onboardingCompleted:
            return nil
        }
    }

    private func reviewActionFor(tab: Tab) {
        guard let url = tab.url else { return }

        if tab != lastVisitTab || url != lastVisitSite {
            lastVisitTab = tab
            lastVisitSite = url
            if url.isDuckDuckGoSearch {
                searchPerformed()
            } else {
                siteVisited()
            }
        }
    }

    private func searchPerformed() {
        switch state {
        case .notStarted:
            state = .initialOnboardingFinished
        case .initialOnboardingFinished:
            state = .searchDone
        case .searchDone:
            state = .searchDoneSeen
        case .siteVisited:
            state = .searchDoneSiteDone
        case .searchDoneSeen:
            state = .searchDoneSeenTrySiteSeen
        case .searchDoneSiteDone:
            state = trackerMessageProvider.isMajorTracker ? .siteVisitedMajorTrackerSeen : .siteVisitedTrackersSeen
        case .siteVisitedMajorTrackerSeen:
            break
        case .siteVisitedTrackersSeen:
            break
        case .siteVisitedFireDone:
            break
        case .searchDoneSeenTrySiteSeen:
            break
        case .onboardingCompleted:
            break
        }
    }

    private func siteVisited() {
        switch state {
        case .notStarted:
            state = .initialOnboardingFinished
        case .initialOnboardingFinished:
            state = .siteVisited
        case .searchDone:
            state = .searchDoneSiteDone
        case .siteVisited:
            state = trackerMessageProvider.isMajorTracker ? .siteVisitedMajorTrackerSeen : .siteVisitedTrackersSeen
        case .searchDoneSeen:
            state = .searchDoneSiteDone
        case .searchDoneSiteDone:
            state = trackerMessageProvider.isMajorTracker ? .siteVisitedMajorTrackerSeen : .siteVisitedTrackersSeen
        case .siteVisitedMajorTrackerSeen:
            break
        case .siteVisitedTrackersSeen:
            break
        case .siteVisitedFireDone:
            break
        case .searchDoneSeenTrySiteSeen:
            break
        case .onboardingCompleted:
            break
        }
    }

    func gotItPressed() {
        switch state {
        case .notStarted:
            break
        case .initialOnboardingFinished:
            break
        case .searchDone:
            state = .searchDoneSeen
        case .siteVisited:
            state = .searchDoneSeen
        case .searchDoneSeen:
            break
        case .searchDoneSiteDone:
            state = .siteVisitedFireDone
        case .siteVisitedMajorTrackerSeen:
            break
        case .siteVisitedTrackersSeen:
            state = .onboardingCompleted
        case .siteVisitedFireDone:
            state = .onboardingCompleted
        case .searchDoneSeenTrySiteSeen:
            break
        case .onboardingCompleted:
            break
        }
    }

}

enum ContextualOnboardingState: String {
    case notStarted
    case initialOnboardingFinished
    case searchDone
    case siteVisited
    case searchDoneSeen
    case searchDoneSiteDone
    case siteVisitedMajorTrackerSeen
    case siteVisitedTrackersSeen
    case siteVisitedFireDone
    case searchDoneSeenTrySiteSeen
    case onboardingCompleted
}

protocol TrackerMessageProviding {
    var isMajorTracker: Bool { get }
}

struct TrackerMessageProvider: TrackerMessageProviding {
    var isMajorTracker: Bool {
        Bool.random()
    }
}
