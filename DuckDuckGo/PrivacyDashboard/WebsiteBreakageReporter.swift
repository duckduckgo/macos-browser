//
//  WebsiteBreakageReporter.swift
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

final class WebsiteBreakageReporter {

    private weak var tabViewModel: TabViewModel?

    public func updateTabViewModel(_ tabViewModel: TabViewModel) {
        self.tabViewModel = tabViewModel
    }

    public func reportBreakage(category: String, description: String) {
        let websiteBreakage = makeWebsiteBreakage(category: category, description: description, currentTab: tabViewModel?.tab)
        let websiteBreakageSender = WebsiteBreakageSender()
        websiteBreakageSender.sendWebsiteBreakage(websiteBreakage)
    }

    private func makeWebsiteBreakage(category: String, description: String, currentTab: Tab?) -> WebsiteBreakage {
        // ⚠️ To limit privacy risk, site URL is trimmed to not include query and fragment
        let currentURL = currentTab?.content.urlForWebView?.trimmingQueryItemsAndFragment()?.absoluteString ?? ""

        let blockedTrackerDomains = currentTab?.privacyInfo?.trackerInfo.trackersBlocked.compactMap { $0.domain } ?? []
        let installedSurrogates = currentTab?.privacyInfo?.trackerInfo.installedSurrogates.map {$0} ?? []
        let ampURL = currentTab?.linkProtection.lastAMPURLString ?? ""
        let urlParametersRemoved = currentTab?.linkProtection.urlParametersRemoved ?? false

        let websiteBreakage = WebsiteBreakage(category: WebsiteBreakage.Category(rawValue: category.lowercased()),
                                              description: description,
                                              siteUrlString: currentURL,
                                              osVersion: "\(ProcessInfo.processInfo.operatingSystemVersion)",
                                              upgradedHttps: currentTab?.privacyInfo?.connectionUpgradedTo != nil,
                                              tdsETag: ContentBlocking.shared.contentBlockingManager.currentRules.first?.etag,
                                              blockedTrackerDomains: blockedTrackerDomains,
                                              installedSurrogates: installedSurrogates,
                                              isGPCEnabled: PrivacySecurityPreferences.shared.gpcEnabled,
                                              ampURL: ampURL,
                                              urlParametersRemoved: urlParametersRemoved)
        return websiteBreakage
    }
}
