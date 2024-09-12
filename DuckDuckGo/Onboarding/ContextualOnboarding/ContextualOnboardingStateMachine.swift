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
    func fireButtonUsed()
//    func dialogDidShow(dialog: ContextualDialogType, on tab: Tab)
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
    
//    func dialogDidShow(dialog: ContextualDialogType, on tab: Tab) {
//
//    }

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
        guard let url = tab.url else { return nil }
        if lastVisitTab != nil && tab != lastVisitTab && url == URL.duckDuckGo && state != .fireButtonSeen  {
            return nil
        }
        reviewActionFor(tab: tab)
        lastVisitTab = tab
        lastVisitSite = url
        if url.isDuckDuckGoSearch {
            return dialogPerSearch()
        } else {
            return dialogPerSiteVisit()
        }
    }

    private func dialogPerSearch() -> ContextualDialogType? {
        switch state {
        case .notStarted:
            return nil
        case .tryASearchShown:
            return nil
        case .searchDoneShown:
            return .searchDone(shouldFollowUp: true)
        case .majorTrackerShown:
            return .searchDone(shouldFollowUp: false)
        case .trackerShown:
            return .searchDone(shouldFollowUp: false)
        case .tryASiteShown:
            return .tryASite
        case .searchDoneMajorTrackerSeen:
            return nil
        case .searchDoneTrackersSeen:
            return nil
        case .fireButtonSeen:
            return .tryFireButton
        case .highFiveSeen:
            return .highFive
        case .onboardingCompleted:
            return nil
        }
    }

    private func dialogPerSiteVisit() -> ContextualDialogType? {
        switch state {
        case .notStarted:
            return nil
        case .tryASearchShown:
            return .tryASearch
        case .searchDoneShown:
            return nil
        case .majorTrackerShown:
            return .trackers(message: NSMutableAttributedString(string: "Some tracker"), shouldFollowUp: true)
        case .trackerShown:
            return .trackers(message: NSMutableAttributedString(string: "Some tracker"), shouldFollowUp: true)
        case .tryASiteShown:
            return nil
        case .searchDoneMajorTrackerSeen:
            return .trackers(message: NSMutableAttributedString(string: "Some tracker"), shouldFollowUp: true)
        case .searchDoneTrackersSeen:
            return .trackers(message: NSMutableAttributedString(string: "Some tracker"), shouldFollowUp: true)
        case .fireButtonSeen:
            return .tryFireButton
        case .highFiveSeen:
            return .highFive
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
            break
        case .tryASearchShown:
            state = .searchDoneShown
        case .searchDoneShown:
            state = .tryASiteShown
        case .majorTrackerShown:
            state = .searchDoneMajorTrackerSeen
        case .trackerShown:
            state = .searchDoneTrackersSeen
        case .tryASiteShown:
            break
        case .searchDoneMajorTrackerSeen:
            state = .fireButtonSeen
        case .searchDoneTrackersSeen:
            state = .fireButtonSeen
        case .fireButtonSeen:
            state = .highFiveSeen
        case .highFiveSeen:
            state = .onboardingCompleted
        case .onboardingCompleted:
            break
        }
    }

    private func siteVisited() {
        switch state {
        case .notStarted:
            state = .tryASearchShown
        case .tryASearchShown:
            state = trackerMessageProvider.isMajorTracker ? .majorTrackerShown : .trackerShown
        case .searchDoneShown:
            state = trackerMessageProvider.isMajorTracker ? .majorTrackerShown : .trackerShown
        case .majorTrackerShown:
            state = .fireButtonSeen
        case .trackerShown:
            state = .fireButtonSeen
        case .tryASiteShown:
            state = trackerMessageProvider.isMajorTracker ? .majorTrackerShown : .trackerShown
        case .searchDoneMajorTrackerSeen:
            state = .fireButtonSeen
        case .searchDoneTrackersSeen:
            state = trackerMessageProvider.isMajorTracker ? .majorTrackerShown : .trackerShown
        case .fireButtonSeen:
            state = .highFiveSeen
        case .highFiveSeen:
            state = .onboardingCompleted
        case .onboardingCompleted:
            break
        }
    }

    func gotItPressed() {
        switch state {
        case .notStarted:
            break
        case .tryASearchShown:
            break
        case .searchDoneShown:
            state = .tryASiteShown
        case .majorTrackerShown:
            state = .fireButtonSeen
        case .trackerShown:
            state = .fireButtonSeen
        case .tryASiteShown:
            break
        case .searchDoneMajorTrackerSeen:
            state = .fireButtonSeen
        case .searchDoneTrackersSeen:
            state = .fireButtonSeen
        case .fireButtonSeen:
            state = .highFiveSeen
        case .highFiveSeen:
            state = .onboardingCompleted
        case .onboardingCompleted:
            break
        }
    }

    func fireButtonUsed() {
        
    }

}

enum ContextualOnboardingState: String {
    case notStarted
    case tryASearchShown
    case searchDoneShown
    case majorTrackerShown
    case trackerShown
    case tryASiteShown
    case searchDoneMajorTrackerSeen
    case searchDoneTrackersSeen
    case fireButtonSeen
    case highFiveSeen
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

















final class ContextualOnboardingStateMachine2: ContextualOnboardingDialogTypeProviding, ContextualOnboardingStateUpdater {

    let trackerMessageProvider: TrackerMessageProviding
    var state: ContextualOnboardingState2 = .notStarted
    var lastVisitTab: Tab?
    var lastVisitSite: URL?
    var lastShownDialog: ContextualDialogType?

    private init(trackerMessageProvider: TrackerMessageProviding = TrackerMessageProvider()) {
        self.trackerMessageProvider = trackerMessageProvider
    }

    static let shared = ContextualOnboardingStateMachine2()

    func dialogTypeForTab(_ tab: Tab) -> ContextualDialogType? {
        guard let url = tab.url else { return nil }
        guard tab != lastVisitTab || url != lastVisitSite else { return lastShownDialog }
        lastVisitTab = tab
        lastVisitSite = url
        if url.isDuckDuckGoSearch {
            return dialogPerSearch()
        } else {
            return dialogPerSiteVisit()
        }
    }

    func dialogDidShow(dialog: ContextualDialogType, on tab: Tab) {
        lastShownDialog = dialog
        switch state {
        case .notStarted:
            if dialog == .tryASearch {
                state = .tryASearchShown
            }
        case .tryASearchShown:
            if case .searchDone = dialog {
                state = .searchDoneShown
            }
            if case .trackers = dialog {
                state = trackerMessageProvider.isMajorTracker ? .majorTrackerShown : .trackerShown
            }
        case .searchDoneShown:
            if case .tryASite = dialog {
                state = .tryASiteShown
            }
            if case .trackers = dialog {
                state = trackerMessageProvider.isMajorTracker ? .majorTrackerShown : .trackerShown
            }
        case .majorTrackerShown:
            if case .searchDone = dialog {
                state = .searchDoneTrackersSeen
            }
            if case .tryFireButton = dialog {
                state = .fireButtonSeen
            }
        case .trackerShown:
            if case .searchDone = dialog {
                state = .searchDoneTrackersSeen
            }
            if case .trackers = dialog {
                state = trackerMessageProvider.isMajorTracker ? .majorTrackerShown : .trackerShown
            }
        case .tryASiteShown:
            if case .trackers = dialog {
                state = trackerMessageProvider.isMajorTracker ? .majorTrackerShown : .trackerShown
            }
        case .searchDoneMajorTrackerSeen:
            if case .tryFireButton = dialog {
                state = .fireButtonSeen
            }
        case .searchDoneTrackersSeen:
            if case .tryFireButton = dialog {
                state = .fireButtonSeen
            }
        case .fireButtonSeen:
            if case .highFive = dialog {
                state = .onboardingCompleted
            }
        case .onboardingCompleted:
            break
        }
    }

    func gotItPressed() {
        switch state {
        case .notStarted:
            break
        case .tryASearchShown:
            break
        case .searchDoneShown:
            state = .tryASiteShown
        case .majorTrackerShown:
            state = .fireButtonSeen
        case .trackerShown:
            state = .fireButtonSeen
        case .tryASiteShown:
            break
        case .searchDoneMajorTrackerSeen:
            state = .fireButtonSeen
        case .searchDoneTrackersSeen:
            state = .fireButtonSeen
        case .fireButtonSeen:
            state = .onboardingCompleted
        case .onboardingCompleted:
            break
        }
    }

    private func dialogPerSearch() -> ContextualDialogType? {
        switch state {
        case .notStarted:
            return .tryASearch
        case .tryASearchShown:
            return .searchDone(shouldFollowUp: true)
        case .searchDoneShown:
            return .tryASite
        case .majorTrackerShown:
            return .searchDone(shouldFollowUp: false)
        case .trackerShown:
            return .searchDone(shouldFollowUp: false)
        case .tryASiteShown:
            return nil
        case .searchDoneMajorTrackerSeen:
            return .tryFireButton
        case .searchDoneTrackersSeen:
            return nil
        case .fireButtonSeen:
            return .highFive
        case .onboardingCompleted:
            return nil
        }
    }

    private func dialogPerSiteVisit() -> ContextualDialogType? {
        switch state {
        case .notStarted:
            return .tryASearch
        case .tryASearchShown:
            return .trackers(message: NSMutableAttributedString(string: "Some tracker"), shouldFollowUp: true)
        case .searchDoneShown:
            return .trackers(message: NSMutableAttributedString(string: "Some tracker"), shouldFollowUp: true)
        case .majorTrackerShown:
            return .tryFireButton
        case .trackerShown:
            if trackerMessageProvider.isMajorTracker {
                return .trackers(message: NSMutableAttributedString(string: "Some tracker"), shouldFollowUp: true)
            }
            return .tryFireButton
        case .tryASiteShown:
            return .trackers(message: NSMutableAttributedString(string: "Some tracker"), shouldFollowUp: true)
        case .searchDoneMajorTrackerSeen:
            return .tryFireButton
        case .searchDoneTrackersSeen:
            return .tryFireButton
        case .fireButtonSeen:
            return .highFive
        case .onboardingCompleted:
            return nil
        }
    }

}

enum ContextualOnboardingState2: String {
    case notStarted
    case tryASearchShown
    case searchDoneShown
    case majorTrackerShown
    case trackerShown
    case tryASiteShown
    case searchDoneMajorTrackerSeen
    case searchDoneTrackersSeen
    case fireButtonSeen
    case onboardingCompleted
}
