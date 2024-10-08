//
//  TrackerMessageProvider.swift
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
import TrackerRadarKit
import BrowserServicesKit

protocol TrackerMessageProviding {
    func trackersType(privacyInfo: PrivacyInfo?) -> OnboardingTrackersType?
    func trackerMessage(privacyInfo: PrivacyInfo?) -> NSAttributedString?
}

struct MajorTrackers {
    static let facebookDomain = "facebook.com"
    static let googleDomain = "google.com"

    static let domains = [facebookDomain, googleDomain]
}

enum OnboardingTrackersType: Equatable {
    case majorTracker
    case ownedByMajorTracker(owner: Entity)
    case blockedTrackers(entityNames: [String])
    case noTrackers
}

struct TrackerMessageProvider: TrackerMessageProviding {

    private var entityProviding: EntityProviding

    init(entityProviding: EntityProviding = AppPrivacyFeatures.shared.contentBlocking.contentBlockingManager) {
        self.entityProviding = entityProviding
    }

    func trackersType(privacyInfo: PrivacyInfo?) -> OnboardingTrackersType? {
        guard let privacyInfo else { return nil }
        guard let host = privacyInfo.domain else { return nil }

        if isFacebookOrGoogle(privacyInfo.url) {
            return .majorTracker
        }

        if let owner = isOwnedByFacebookOrGoogle(host) {
            return .ownedByMajorTracker(owner: owner)
        }

        if let entityNames = blockedEntityNames(privacyInfo.trackerInfo) {
            return .blockedTrackers(entityNames: entityNames)
        }

        return .noTrackers
    }

    func trackerMessage(privacyInfo: PrivacyInfo?) -> NSAttributedString? {
        guard let privacyInfo else { return nil }
        guard let host = privacyInfo.domain else { return nil }
        guard let trackerType = trackersType(privacyInfo: privacyInfo) else { return nil }
        var message: String?
        switch trackerType {
        case .majorTracker:
            message = majorTrackerMessage(host)
        case .ownedByMajorTracker(let owner):
            message = majorTrackerOwnerMessage(host, owner)
        case .blockedTrackers(let entityNames):
            message = trackersBlockedMessage(entityNames)
        case .noTrackers:
            message = UserText.ContextualOnboarding.daxDialogBrowsingWithoutTrackers
        }
        guard let message else { return nil }
        return attributedString(from: message, fontSize: OnboardingDialogsContants.messageFontSize)
    }

    private func isFacebookOrGoogle(_ url: URL) -> Bool {
        return [ MajorTrackers.facebookDomain, MajorTrackers.googleDomain ].contains { domain in
            return url.isPart(ofDomain: domain)
        }
    }

    private func isOwnedByFacebookOrGoogle(_ host: String) -> Entity? {
        guard let entity = entityProviding.entity(forHost: host) else { return nil }
        return entity.domains?.contains(where: { MajorTrackers.domains.contains($0) }) ?? false ? entity : nil
    }

    private func majorTrackerMessage(_ host: String) -> String? {
        guard let entityName = entityProviding.entity(forHost: host)?.displayName else { return nil }
        let message = UserText.ContextualOnboarding.daxDialogBrowsingSiteIsMajorTracker
        return String(format: message, entityName, host)
    }

    private func majorTrackerOwnerMessage(_ host: String, _ majorTrackerEntity: Entity) -> String? {
        guard let entityName = majorTrackerEntity.displayName,
            let entityPrevalence = majorTrackerEntity.prevalence else { return nil }
        let message = UserText.ContextualOnboarding.daxDialogBrowsingSiteOwnedByMajorTracker
        return String(format: message, host.droppingWwwPrefix(),
                      entityName,
                      entityPrevalence)
    }

    private func blockedEntityNames(_ trackerInfo: TrackerInfo) -> [String]? {
        guard !trackerInfo.trackersBlocked.isEmpty else { return nil }

        return trackerInfo.trackersBlocked.removingDuplicates { $0.entityName }
            .sorted(by: { $0.prevalence ?? 0.0 > $1.prevalence ?? 0.0 })
            .compactMap { $0.entityName }
    }

    private func trackersBlockedMessage(_ entitiesBlocked: [String]) -> String? {
        switch entitiesBlocked.count {
        case 0:
            return nil

        case 1:
            let args = entitiesBlocked[0]
            let message = UserText.ContextualOnboarding.daxDialogBrowsingWithOneTracker
            return String(format: message, args)

        case 2:
            let args: [CVarArg]  = [entitiesBlocked[0], entitiesBlocked[1]]
            let message = UserText.ContextualOnboarding.daxDialogBrowsingWithTwoTrackers
            return String(format: message, args)

        default:
            let args: [CVarArg] = [entitiesBlocked.count - 2, entitiesBlocked[0], entitiesBlocked[1]]
            let message = UserText.ContextualOnboarding.daxDialogBrowsingWithMultipleTrackers
            return String(format: message, args)
        }
    }

    private func attributedString(from string: String, fontSize: CGFloat) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()

        var isBold = false
        var currentText = ""

        for character in string {
            if character == "*" {
                if !currentText.isEmpty {
                    let attributes: [NSAttributedString.Key: Any] = isBold ?
                        [.font: NSFont.systemFont(ofSize: fontSize, weight: .bold)] :
                        [:]
                    attributedString.append(NSAttributedString(string: currentText, attributes: attributes))
                    currentText = ""
                }
                isBold.toggle()
            } else {
                currentText.append(character)
            }
        }

        if !currentText.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = isBold ?
                [.font: NSFont.systemFont(ofSize: fontSize, weight: .bold)] :
                [:]
            attributedString.append(NSAttributedString(string: currentText, attributes: attributes))
        }

        return attributedString
    }
}

extension ContentBlockerRulesManager: EntityProviding {
    func entity(forHost host: String) -> Entity? {
        currentMainRules?.trackerData.findParentEntityOrFallback(forHost: host)
    }
}

protocol EntityProviding {
    func entity(forHost host: String) -> Entity?
}
