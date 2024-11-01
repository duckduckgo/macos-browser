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
import PrivacyDashboard

protocol ContextualOnboardingDialogTypeProviding {
    func dialogTypeForTab(_ tab: Tab, privacyInfo: PrivacyInfo?) -> ContextualDialogType?
}

protocol ContextualOnboardingStateUpdater: AnyObject {
    var state: ContextualOnboardingState { get }
    func updateStateFor(tab: Tab)
    func gotItPressed()
    func fireButtonUsed()
    func turnOffFeature()
}

protocol FireButtonInfoStateProviding {
    var infoPresentedOnce: Bool { get set }
}

final class FireButtonInfoStateProvider: FireButtonInfoStateProviding {
    @UserDefaultsWrapper(key: .fireInfoPresentedOnce, defaultValue: false)
     var infoPresentedOnce: Bool
}

enum ContextualDialogType: Equatable {
    case tryASearch
    case searchDone(shouldFollowUp: Bool)
    case tryASite
    case trackers(message: NSAttributedString, shouldFollowUp: Bool)
    case tryFireButton
    case highFive
}

enum ContextualOnboardingState: String, CaseIterable {

    // The contextual onboarding has not started. This state should apply only during the linear onboarding.
    case notStarted

    // State as soon as we load the initial page after onboarding.
    // It will show the "Try a search" dialog after the first visit.
    // From this state, after a website visit, it will show a "Tracker" dialog.
    // From this state, after a search, it will show the "Try visit a site" dialog.
    case showTryASearch

    // State applied after the first search if no website visit occurred before.
    // From this state, after a website visit, it will show a "Tracker" dialog.
    // From this state, after a search, it will show nothing.
    case showSearchDone

    // State applied after the first time a site is visited where trackers were blocked, and no search occurred before.
    // From this state, after a website visit, it will show the "Try Fire Button" dialog.
    // From this state, after a search, it will show the "Search Done" dialog.
    case showBlockedTrackers

    // State applied after the first time a site is visited where no trackers were blocked, and no search occurred before.
    // From this state, after a website visit, it will show a "Tracker" dialog if a tracker is blocked; otherwise, nothing.
    // From this state, after a search, it will show the "Search Done" dialog.
    case showMajorOrNoTracker

    // State applied after the first search and the "Search Done" dialog has been seen.
    // From this state, after a website visit, it will show a "Tracker" dialog.
    // From this state, after a search, it will show nothing.
    case showTryASite

    // State applied after the first search and the "Try A Site" dialog has been seen.
    // From this state, after a website visit, it will show a "Tracker" dialog.
    // From this state, after a search, it will show nothing.
    case tryASiteSeen

    // State applied after the first time a site is visited where trackers were blocked, and a search occurred before.
    // From this state, after a website visit, it will show the "Try Fire Button" dialog.
    // From this state, after a search, it will show the "Search Done" dialog.
    case searchDoneShowBlockedTrackers

    // State applied after the first time a site is visited where no trackers were blocked, and a search occurred before.
    // From this state, after a website visit, it will show a "Tracker" dialog if a tracker is blocked; otherwise, nothing.
    // From this state, after a search, it will show the "Search Done" dialog.
    case searchDoneShowMajorOrNoTracker

    // State applied after a searchDone dialog is seen and blocked tracker were previously seen.
    // From this state, after a website visit, it will show the "Try Fire Button" dialog.
    // From this state, after a search, it will show nothing.
    case searchDoneSeenShowBlockedTrackers

    // State applied after a searchDone dialog is seen and blocked tracker were previously seen.
    // From this state, after a website visit, it will show the "Try Fire Button" dialog.
    // From this state, after a search, it will show nothing.
    case searchDoneSeenShowMajorOrNoTracker

    // State applied when, after the "Try a search" dialog is displayed, the fire button is used.
    // From this state, after a website visit, it will show a "Tracker" dialog.
    // From this state, after a search, it will transition to "fireUsedShowSearchDone".
    case fireUsedTryASearchShown

    // State applied after a search is performed in the "fireUsedTryASearchShown" state.
    // From this state, after a website visit, it will show a "Tracker" dialog.
    // From this state, after a search, it will show the "Search Done" dialog.
    case fireUsedShowSearchDone

    // State applied when "Got it" is pressed on a tracker or after a visit if performed after blocked trackers.
    // From this state, after a website visit, it will show the "Try Fire Button" dialog.
    // From this state, after a search, it will show the "Try Fire Button" dialog.
    case showFireButton

    // State applied after any action once the "Try Fire Button" dialog is shown.
    // From this state, after a website visit, it will show the "High Five" dialog.
    // From this state, after a search, it will show the "High Five" dialog.
    case showHighFive

    // State applied after any action once the "High Five" dialog is shown, indicating the end of the contextual onboarding.
    // From this state, after a website visit, it will show nothing.
    // From this state, after a search, it will show nothing.
    case onboardingCompleted
}

final class ContextualOnboardingStateMachine: ContextualOnboardingDialogTypeProviding, ContextualOnboardingStateUpdater {

    private let trackerMessageProvider: TrackerMessageProviding
    private let startUpPreferences: StartupPreferences
    private var fireButtonInfoStateProvider: FireButtonInfoStateProviding
    private var fireButtonUsedOnce: Bool = false

    @UserDefaultsWrapper(key: .contextualOnboardingState, defaultValue: ContextualOnboardingState.onboardingCompleted.rawValue)
    private var stateString: String {
        didSet {
            if stateString == ContextualOnboardingState.notStarted.rawValue {
                // This makes the home page DuckDuckGo during the onboarding
                startUpPreferences.launchToCustomHomePage = true
                // This avoids the info sheet on the Fire button popover to be shown during the onboarding
                fireButtonInfoStateProvider.infoPresentedOnce = true
                resetData()
            }
            if stateString == ContextualOnboardingState.onboardingCompleted.rawValue {
                // If the user has not used the fire button 
                // it will present the info sheet on the Fire button popover when they click on it for the first time
                if !fireButtonUsedOnce {
                    fireButtonInfoStateProvider.infoPresentedOnce = false
                }
                // This resets the home page to be the new tab page after the onboarding
                startUpPreferences.launchToCustomHomePage = false
                resetData()
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

    private weak var lastVisitTab: Tab?
    private var lastVisitSite: URL?
    private var notBlockedTrackerSeen: Bool = false

    init(trackerMessageProvider: TrackerMessageProviding = TrackerMessageProvider(),
         startupPreferences: StartupPreferences = StartupPreferences.shared,
         fireButtonInfoStateProvider: FireButtonInfoStateProviding = FireButtonInfoStateProvider()) {
        self.trackerMessageProvider = trackerMessageProvider
        self.startUpPreferences = startupPreferences
        self.fireButtonInfoStateProvider = fireButtonInfoStateProvider
    }

    func dialogTypeForTab(_ tab: Tab, privacyInfo: PrivacyInfo? = nil) -> ContextualDialogType? {
        let info = privacyInfo ?? tab.privacyInfo
        guard case .url = tab.content else {
            return nil
        }
        guard let url = tab.url else { return nil }

        // This is to avoid showing a dialog immediately when the user opens a new Window
        if isANewWindow(tab: tab, url: url) {
            lastVisitTab = tab
            lastVisitSite = url
            return nil
        }

        lastVisitTab = tab
        lastVisitSite = url
        if url.isDuckDuckGoSearch {
            return dialogPerSearch()
        } else {
            return dialogPerSiteVisit(privacyInfo: info)
        }
    }

    private func dialogPerSearch() -> ContextualDialogType? {
        switch state {
        case .showSearchDone, .fireUsedShowSearchDone:
            return .searchDone(shouldFollowUp: true)
        case .showBlockedTrackers, .showMajorOrNoTracker, .searchDoneShowBlockedTrackers, .searchDoneShowMajorOrNoTracker:
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

    private func dialogPerSiteVisit(privacyInfo: PrivacyInfo?) -> ContextualDialogType? {
        switch state {
        case .showTryASearch:
            return .tryASearch
        case .showMajorOrNoTracker, .searchDoneShowMajorOrNoTracker, .searchDoneSeenShowMajorOrNoTracker:
            if !notBlockedTrackerSeen {
                return trackerDialog(for: privacyInfo)
            }
            return nil
        case .showBlockedTrackers, .searchDoneShowBlockedTrackers, .searchDoneSeenShowBlockedTrackers, .fireUsedShowSearchDone:
            return trackerDialog(for: privacyInfo)
        case .showFireButton:
            return .tryFireButton
        case .showHighFive:
            return .highFive
        default:
            return nil
        }
    }

    private func resetData() {
        lastVisitTab = nil
        lastVisitSite = nil
        notBlockedTrackerSeen = false
    }

    // To determine if it's a new Window we do the following:
    // Check if some action has been taken (e.g. it is not the start of the contextual onboarding)
    // If lastVisitedTab is not the same as current tab (e.g. it's not a reload)
    // And the state is not showFireButton (e.g. we have not used the Fire button on the same Window)
    private func isANewWindow(tab: Tab, url: URL) -> Bool {
        return lastVisitTab != nil && tab != lastVisitTab && url == URL.duckDuckGo && state != .showFireButton
    }

    private func trackerDialog(for privacyInfo: PrivacyInfo?) -> ContextualDialogType? {
        guard let privacyInfo else { return nil }
        guard let message = trackerMessageProvider.trackerMessage(privacyInfo: privacyInfo) else { return nil }
        return .trackers(message: message, shouldFollowUp: true)
    }

    func updateStateFor(tab: Tab) {
        guard case .url = tab.content else {
            return
        }
        guard let url = tab.url else { return }

        // This is to avoid updating the state immediately when the user opens a new Window (and DuckDuckGo site is loaded)
        if isANewWindow(tab: tab, url: url) {
            lastVisitTab = tab
            lastVisitSite = url
            return
        }

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
        case .showTryASite:
            state = .tryASiteSeen
        case .showBlockedTrackers:
            state = .searchDoneShowBlockedTrackers
        case .showMajorOrNoTracker:
            state = .searchDoneShowMajorOrNoTracker
        case .searchDoneShowBlockedTrackers:
            state = .searchDoneSeenShowBlockedTrackers
        case .searchDoneShowMajorOrNoTracker:
            state = .searchDoneSeenShowMajorOrNoTracker
        case .searchDoneSeenShowBlockedTrackers, .searchDoneSeenShowMajorOrNoTracker:
            state = .showFireButton
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
        case .showTryASearch, .fireUsedTryASearchShown:
            if case .blockedTrackers = trackerType {
                state = .showBlockedTrackers
            } else if trackerType != nil {
                state = .showMajorOrNoTracker
            }
        case .showSearchDone, .showTryASite, .tryASiteSeen:
            if case .blockedTrackers = trackerType {
                state = .searchDoneSeenShowBlockedTrackers
            } else if trackerType != nil {
                state = .searchDoneSeenShowMajorOrNoTracker
            }
        case .showBlockedTrackers, .searchDoneShowBlockedTrackers, .searchDoneSeenShowBlockedTrackers:
            state = .showFireButton
        case .showMajorOrNoTracker, .searchDoneShowMajorOrNoTracker, .searchDoneSeenShowMajorOrNoTracker:
            if case .blockedTrackers = trackerType {
                state = .showBlockedTrackers
            } else {
                notBlockedTrackerSeen = true
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
        case .showBlockedTrackers, .showMajorOrNoTracker, .searchDoneShowBlockedTrackers, .searchDoneShowMajorOrNoTracker, .searchDoneSeenShowBlockedTrackers, .searchDoneSeenShowMajorOrNoTracker:
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
        fireButtonUsedOnce = true
        switch state {
        case .showTryASearch:
            state = .fireUsedTryASearchShown
        case .fireUsedShowSearchDone:
            state = .showHighFive
        case .showBlockedTrackers, .showMajorOrNoTracker, .showTryASite, .tryASiteSeen, .searchDoneShowBlockedTrackers, .searchDoneSeenShowBlockedTrackers, .searchDoneShowMajorOrNoTracker, .searchDoneSeenShowMajorOrNoTracker, .showSearchDone:
            state = .showFireButton
        case .showHighFive:
            state = .onboardingCompleted
        default:
            break
        }
    }

    func turnOffFeature() {
        state = .onboardingCompleted
    }
}
