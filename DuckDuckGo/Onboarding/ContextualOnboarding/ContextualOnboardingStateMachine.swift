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
    case showTryASearch
    case showSearchDone
    case showBlockedTrackers
    case showMajorOrNoTracker
    case showTryASite
    case searchDoneShowBlockedTrackers
    case searchDoneShowMajorOrNoTracker
    case fireUsedTryASearchShown
    case fireUsedShowSearchDone
    case showFireButton
    case showHighFive
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

    init(trackerMessageProvider: TrackerMessageProviding = TrackerMessageProvider(),
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

        if lastVisitTab != nil && tab != lastVisitTab && url == URL.duckDuckGo && state != .showFireButton  {
            return nil
        }
        reviewActionFor(tab: tab)
        lastVisitTab = tab
        lastVisitSite = url
        print("STATE END \(state)")
        if url.isDuckDuckGoSearch {
            return dialogPerSearch()
        } else {
            return dialogPerSiteVisit(tab: tab)
        }
    }

    private func dialogPerSearch() -> ContextualDialogType? {
        switch state {
        case .showSearchDone, .fireUsedShowSearchDone:
            return .searchDone(shouldFollowUp: true)
        case .showBlockedTrackers, .showMajorOrNoTracker:
            return .searchDone(shouldFollowUp: false)
        case .showTryASite:
            return .tryASite
        case .showFireButton:
            return .tryFireButton
        case .showHighFive:
            return .highFive
        default:
            return nil
        }
    }

    private func dialogPerSiteVisit(tab: Tab) -> ContextualDialogType? {
        switch state {
        case .showTryASearch:
            return .tryASearch
        case .showBlockedTrackers, .showMajorOrNoTracker, .searchDoneShowBlockedTrackers, .searchDoneShowMajorOrNoTracker, .fireUsedShowSearchDone:
            guard let privacyInfo = tab.privacyInfo else { return nil }
            guard let message = trackerMessageProvider.trackerMessage(privacyInfo: privacyInfo) else { return nil }
            return .trackers(message: message, shouldFollowUp: true)
        case .showFireButton:
            return .tryFireButton
        case .showHighFive:
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
                siteVisited(tab: tab)
            }
        }
    }

    private func searchPerformed() {
        switch state {
        case .showTryASearch:
            state = .showSearchDone
        case .showSearchDone:
            state = .showTryASite
        case .showBlockedTrackers:
            state = .searchDoneShowBlockedTrackers
        case .showMajorOrNoTracker:
            state = .searchDoneShowMajorOrNoTracker
        case .searchDoneShowBlockedTrackers, .searchDoneShowMajorOrNoTracker:
            state = .showTryASite
        case .showFireButton, .fireUsedShowSearchDone:
            state = .showHighFive
        case .showHighFive:
            state = .onboardingCompleted
        case .fireUsedTryASearchShown:
            state = .fireUsedShowSearchDone
        default:
            break
        }
    }

    private func siteVisited(tab: Tab) {
        let trackerType = trackerMessageProvider.trackersType(privacyInfo: tab.privacyInfo)

        switch state {
        case .notStarted:
            state = .showTryASearch
        case .showTryASearch, .showTryASite, .fireUsedTryASearchShown:
            if case .blockedTrackers = trackerType {
                state = .showBlockedTrackers
            } else if trackerType != nil {
                state = .showMajorOrNoTracker
            }
        case .showSearchDone:
            if case .blockedTrackers = trackerType {
                state = .searchDoneShowBlockedTrackers
            } else if trackerType != nil {
                state = .searchDoneShowMajorOrNoTracker
            }
        case .showBlockedTrackers, .searchDoneShowBlockedTrackers:
            state = .showFireButton
        case .showMajorOrNoTracker, .searchDoneShowMajorOrNoTracker:
            if case .blockedTrackers = trackerType {
                state = .showBlockedTrackers
            }
        case .fireUsedShowSearchDone:
            state = .showFireButton
        case .showFireButton:
            state = .showHighFive
        case .showHighFive:
            state = .onboardingCompleted
        case .onboardingCompleted:
            break
        }
    }

    func gotItPressed() {
        switch state {
        case .showSearchDone, .fireUsedShowSearchDone:
            state = .showTryASite
        case .showBlockedTrackers, .showMajorOrNoTracker, .searchDoneShowBlockedTrackers, .searchDoneShowMajorOrNoTracker:
            state = .showFireButton
        case .showFireButton:
            state = .showHighFive
        case .showHighFive:
            state = .onboardingCompleted
        default:
            break
        }
    }

    func fireButtonUsed() {
        switch state {
        case .showTryASearch:
            state = .fireUsedTryASearchShown
        case .fireUsedShowSearchDone:
            state = .showHighFive
        case .showMajorOrNoTracker, .showTryASite, .searchDoneShowBlockedTrackers, .searchDoneShowMajorOrNoTracker, .showSearchDone:
            state = .showFireButton
        case .showHighFive:
            state = .onboardingCompleted
        default:
            break
        }
    }
}
