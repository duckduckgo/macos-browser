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
}

enum ContextualDialogType: Equatable {
    case tryASearch
    case searchDone(shouldFollowUp: Bool)
    case tryASite
    case trackers(message: NSAttributedString, shouldFollowUp: Bool)
    case tryFireButton
    case highFive
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
    case fireUsedTryASearchShown
    case fireUsedSearchDone
    case searchDoneSiteNot
    case fireButtonSeen
    case highFiveSeen
    case onboardingCompleted
}

final class ContextualOnboardingStateMachine: ContextualOnboardingDialogTypeProviding, ContextualOnboardingStateUpdater {

    let trackerMessageProvider: TrackerMessageProviding
    let startUpPreferences: StartupPreferences

    @UserDefaultsWrapper(key: .contextualOnboardingState, defaultValue: ContextualOnboardingState.onboardingCompleted.rawValue)
    private var stateString: String {
        didSet {
            if stateString == ContextualOnboardingState.notStarted.rawValue {
                startUpPreferences.launchToCustomHomePage = true
                lastVisitTab = nil
                lastVisitSite = nil
            }
            if stateString == ContextualOnboardingState.onboardingCompleted.rawValue {
                startUpPreferences.launchToCustomHomePage = false
            }
        }
    }

    var state: ContextualOnboardingState {
        get {
            return ContextualOnboardingState(rawValue: stateString) ?? .onboardingCompleted
        }
        set {
            stateString = newValue.rawValue
        }
    }

    var lastVisitTab: Tab?
    var lastVisitSite: URL?

    private init(trackerMessageProvider: TrackerMessageProviding = TrackerMessageProvider(),
                 startupPreferences: StartupPreferences = StartupPreferences.shared) {
        self.trackerMessageProvider = trackerMessageProvider
        self.startUpPreferences = startupPreferences
    }

    static let shared = ContextualOnboardingStateMachine()

    func dialogTypeForTab(_ tab: Tab) -> ContextualDialogType? {
        print("STATE START \(state)")
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
        print("STATE END \(state)")
        if url.isDuckDuckGoSearch {
            return dialogPerSearch()
        } else {
            return dialogPerSiteVisit()
        }
    }

    private func dialogPerSearch() -> ContextualDialogType? {
        switch state {
        case .searchDoneShown, .fireUsedSearchDone:
            return .searchDone(shouldFollowUp: true)
        case .majorTrackerShown, .trackerShown:
            return .searchDone(shouldFollowUp: false)
        case .tryASiteShown:
            return .tryASite
        case .fireButtonSeen:
            return .tryFireButton
        case .highFiveSeen:
            return .highFive
        default:
            return nil
        }
    }

    private func dialogPerSiteVisit() -> ContextualDialogType? {
        switch state {
        case .tryASearchShown:
            return .tryASearch
        case .majorTrackerShown, .trackerShown, .searchDoneMajorTrackerSeen, .searchDoneTrackersSeen, .fireUsedSearchDone, .searchDoneSiteNot:
            return .trackers(message: NSMutableAttributedString(string: "Some tracker"), shouldFollowUp: true)
        case .fireButtonSeen:
            return .tryFireButton
        case .highFiveSeen:
            return .highFive
        default:
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
        case .tryASearchShown:
            state = .searchDoneShown
        case .searchDoneShown:
            state = .tryASiteShown
        case .majorTrackerShown:
            state = .searchDoneMajorTrackerSeen
        case .trackerShown:
            state = .searchDoneTrackersSeen
        case .tryASiteShown:
            state = .searchDoneSiteNot
        case .searchDoneMajorTrackerSeen, .searchDoneTrackersSeen:
            state = .fireButtonSeen
        case .fireButtonSeen, .fireUsedSearchDone:
            state = .highFiveSeen
        case .highFiveSeen:
            state = .onboardingCompleted
        case .fireUsedTryASearchShown:
            state = .fireUsedSearchDone
        default:
            break
        }
    }

    private func siteVisited() {
        switch state {
        case .notStarted:
            state = .tryASearchShown
        case .tryASearchShown, .searchDoneShown, .searchDoneSiteNot:
            state = trackerMessageProvider.isMajorTracker ? .searchDoneMajorTrackerSeen : .searchDoneTrackersSeen
        case .majorTrackerShown, .trackerShown, .searchDoneMajorTrackerSeen:
            state = .fireButtonSeen
        case .tryASiteShown, .searchDoneTrackersSeen, .fireUsedTryASearchShown:
            state = trackerMessageProvider.isMajorTracker ? .majorTrackerShown : .trackerShown
        case .fireButtonSeen, .fireUsedSearchDone:
            state = .highFiveSeen
        case .highFiveSeen:
            state = .onboardingCompleted
        case .onboardingCompleted:
            break
        }
    }

    func gotItPressed() {
        switch state {
        case .searchDoneShown, .fireUsedSearchDone:
            state = .tryASiteShown
        case .majorTrackerShown, .trackerShown, .searchDoneMajorTrackerSeen, .searchDoneTrackersSeen:
            state = .fireButtonSeen
        case .fireButtonSeen:
            state = .highFiveSeen
        case .highFiveSeen:
            state = .onboardingCompleted
        default:
            break
        }
    }

    func fireButtonUsed() {
        switch state {
        case .tryASearchShown:
            state = .fireUsedTryASearchShown
        case .fireUsedSearchDone, .searchDoneSiteNot:
            state = .highFiveSeen
        case .trackerShown, .tryASiteShown, .searchDoneMajorTrackerSeen, .searchDoneTrackersSeen, .searchDoneShown:
            state = .fireButtonSeen
        case .highFiveSeen:
            state = .onboardingCompleted
        default:
            break
        }
    }
}

protocol TrackerMessageProviding {
    var isMajorTracker: Bool { get }
}

struct TrackerMessageProvider: TrackerMessageProviding {
    var isMajorTracker: Bool {
        Bool.random()
    }
}
