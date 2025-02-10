//
//  NewTabPagePixel.swift
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
import PixelKit

/**
 * This enum keeps pixels related to HTML New Tab Page.
 */
enum NewTabPagePixel: PixelKitEventV2 {

    /**
     * Event Trigger: New Tab Page is displayed to user.
     *
     * > Note: This is a daily pixel.
     *
     * > Related links:
     * [Privacy Triage](https://app.asana.com/0/69071770703008/1209254338283658/f)
     * [Detailed Pixels description](https://app.asana.com/0/72649045549333/1209247985805453/f)
     *
     * Anomaly Investigation:
     * - Anomaly in this pixel may mean an increase/drop in app use.
     */
    case newTabPageShown(favorites: Bool, recentActivity: Bool?, privacyStats: Bool?, customBackground: Bool)

    /**
     * Event Trigger: Favorites section on NTP is hidden.
     *
     * > Related links:
     * [Privacy Triage](https://app.asana.com/0/69071770703008/1209254338283658/f)
     * [Detailed Pixels description](https://app.asana.com/0/72649045549333/1209247985805453/f)
     *
     * Anomaly Investigation:
     * - Anomaly in this pixel may mean an increase/drop in app use.
     * - The pixel is fired from `AppearancePreferences` so an anomaly may mean a bug in the code
     *   causing the setter to be called too many times.
     */
    case favoriteSectionHidden

    /**
     * Event Trigger: A link in Privacy Feed (a.k.a. Recent Activity) is activated.
     *
     * > Related links:
     * [Privacy Triage](https://app.asana.com/0/69071770703008/1209316863206567)
     *
     * Anomaly Investigation:
     * - Anomaly in this pixel may mean an increase/drop in app use.
     * - This pixel is fired from `DefaultRecentActivityActionsHandler` when handling `open` JS message.
     */
    case privacyFeedHistoryLinkOpened

    /**
     * Event Trigger: Recent Activity section on NTP is hidden.
     *
     * > Related links:
     * [Privacy Triage](https://app.asana.com/0/69071770703008/1209254338283658/f)
     * [Detailed Pixels description](https://app.asana.com/0/72649045549333/1209247985805453/f)
     *
     * Anomaly Investigation:
     * - Anomaly in this pixel may mean an increase/drop in app use.
     * - The pixel is fired from `AppearancePreferences` so an anomaly may mean a bug in the code
     *   causing the setter to be called too many times.
     */
    case recentActivitySectionHidden

    /**
     * Event Trigger: Recent Activity section on NTP is hidden.
     *
     * > Related links:
     * [Privacy Triage](https://app.asana.com/0/69071770703008/1209254338283658/f)
     * [Detailed Pixels description](https://app.asana.com/0/72649045549333/1209247985805453/f)
     *
     * Anomaly Investigation:
     * - Anomaly in this pixel may mean an increase/drop in app use.
     * - The pixel is fired from `AppearancePreferences` so an anomaly may mean a bug in the code
     *   causing the setter to be called too many times.
     */
    case blockedTrackingAttemptsSectionHidden

    /**
     * Event Trigger: "Show Less" button is clicked in Privacy Stats table on the New Tab Page, to collapse the table.
     *
     * > Note: This isn't the section collapse setting (like for Favorites or Next Steps), but the sub-setting
     *   to control whether the view should contain 5 most frequently blocked top companies or all top companies.
     *
     * Anomaly Investigation:
     * - This pixel is fired from `NewTabPagePrivacyStatsModel` in response to a message sent by the user script.
     * - In case of anomalies, check if the subscription between the user script and the model isn't causing the pixel
     *   to be fired more than once per interaction.
     */
    case blockedTrackingAttemptsShowLess

    /**
     * Event Trigger: "Show More" button is clicked in Privacy Stats table on the New Tab Page, to expand the table.
     *
     * > Note: This isn't the section collapse setting (like for Favorites or Next Steps), but the sub-setting
     *   to control whether the view should contain 5 most frequently blocked top companies or all top companies.
     *
     * Anomaly Investigation:
     * - This pixel is fired from `NewTabPagePrivacyStatsModel` in response to a message sent by the user script.
     * - In case of anomalies, check if the subscription between the user script and the model isn't causing the pixel
     *   to be fired more than once per interaction.
     */
    case blockedTrackingAttemptsShowMore

    // MARK: - Debug

    /**
     * Event Trigger: Privacy Stats database fails to be initialized. Firing this pixel is followed by an app crash with a `fatalError`.
     * This pixel can be fired when there's no space on disk, when database migration fails or when database was tampered with.
     * This is a debug (health) pixel.
     *
     * > Related links:
     * [Privacy Triage](https://app.asana.com/0/69071770703008/1208953986023007/f)
     * [Detailed Pixels description](https://app.asana.com/0/1199230911884351/1208936504720914/f)
     *
     * Anomaly Investigation:
     * - If this spikes in production it may mean we've released a new PriacyStats database model version
     *   and didn't handle migration correctly in which case we need a hotfix.
     * - Otherwise it may happen occasionally for users with not space left on device.
     */
    case privacyStatsCouldNotLoadDatabase

    /**
     * Event Trigger: Privacy Stats reports a database error when fetching, storing or clearing data,
     * as outlined by `PrivacyStatsError`. This is a debug (health) pixel.
     *
     * > Related links:
     * [Privacy Triage](https://app.asana.com/0/69071770703008/1208953986023007/f)
     * [Detailed Pixels description](https://app.asana.com/0/1199230911884351/1208936504720914/f)
     *
     * Anomaly Investigation:
     * - The errors here are all Core Data errors. The error code identifies the specific enum case of `PrivacyStatsError`.
     * - Check `PrivacyStats` for places where the error is thrown.
     */
    case privacyStatsDatabaseError

    case newTabPageExceptionReported(message: String)

    var name: String {
        switch self {
        case .newTabPageShown: return "m_mac_newtab_shown"
        case .favoriteSectionHidden: return "m_mac_favorite-section-hidden"
        case .privacyFeedHistoryLinkOpened: return "m_mac_privacy_feed_history_link_opened"
        case .recentActivitySectionHidden: return "m_mac_recent-activity-section-hidden"
        case .blockedTrackingAttemptsSectionHidden: return "m_mac_blocked-tracking-attempts-section-hidden"
        case .blockedTrackingAttemptsShowLess: return "m_mac_new-tab-page_blocked-tracking-attempts_show-less"
        case .blockedTrackingAttemptsShowMore: return "m_mac_new-tab-page_blocked-tracking-attempts_show-more"
        case .privacyStatsCouldNotLoadDatabase: return "new-tab-page_privacy-stats_could-not-load-database"
        case .privacyStatsDatabaseError: return "new-tab-page_privacy-stats_database_error"
        case .newTabPageExceptionReported: return "new-tab-page_exception-reported"
        }
    }

    var parameters: [String: String]? {
        switch self {
        case .newTabPageShown(let favorites, let recentActivity, let privacyStats, let customBackground):
            var parameters = [
                "favorites": String(favorites),
                "background": customBackground ? "custom" : "default"
            ]
            if let recentActivity {
                parameters["recent-activity"] = String(recentActivity)
            }
            if let privacyStats {
                parameters["blocked-tracking-attempts"] = String(privacyStats)
            }
            return parameters
        case .newTabPageExceptionReported(let message):
            return [PixelKit.Parameters.assertionMessage: message]
        case .favoriteSectionHidden,
                .recentActivitySectionHidden,
                .blockedTrackingAttemptsSectionHidden,
                .blockedTrackingAttemptsShowLess,
                .blockedTrackingAttemptsShowMore,
                .privacyFeedHistoryLinkOpened,
                .privacyStatsCouldNotLoadDatabase,
                .privacyStatsDatabaseError:
            return nil
        }
    }

    var error: (any Error)? {
        nil
    }
}
