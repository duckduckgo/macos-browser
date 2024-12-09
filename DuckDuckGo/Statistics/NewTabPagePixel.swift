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
 *
 * > Related links:
 * [Privacy Triage](https://app.asana.com/0/69071770703008/1208146890364172/f)
 * [Detailed Pixels description](https://app.asana.com/0/1201621708115095/1207983904350396/f)
 */
enum NewTabPagePixel: PixelKitEventV2 {

    // MARK: - Debug

    /**
     * Event Trigger: Privacy Stats reports a database error, as outlined by `PrivacyStatsError`. This is a debug (health) pixel.
     *
     * Anomaly Investigation:
     * - The errors here are all Core Data errors. The error code identifies the specific enum case of `PrivacyStatsError`.
     * - Check `PrivacyStats` for places where the error is thrown.
     */
    case privacyStatsDatabaseError

    var name: String {
        switch self {
        case .privacyStatsDatabaseError: return "m_mac_new-tab-page.privacy-stats.database.error"
        }
    }

    var parameters: [String: String]? {
        nil
    }

    var error: (any Error)? {
        nil
    }
}
