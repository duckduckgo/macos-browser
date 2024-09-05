//
//  NewTabBackgroundPixel.swift
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
 * This enum keeps pixels related to New Tab page background customization.
 *
 * > Related links:
 * [Privacy Triage](https://app.asana.com/0/69071770703008/1208146890364172/f)
 * [Detailed Pixels description](https://app.asana.com/0/1201621708115095/1207983904350396/f)
 */
enum NewTabBackgroundPixel: PixelKitEventV2 {

    /**
     * Event Trigger: User selects gradient as custom NTP background.
     *
     * Anomaly Investigation:
     * - `customBackground` is updated with this value from `HomePage.Models.SettingsModel` and `HomePage.Views.BackgroundPickerView`.
     * - Check the above places in code and make sure nothing got broken to cause the update to be fired repeatedly.
     */
    case newTabBackgroundSelectedGradient

    /**
     * Event Trigger: User selects solid color as custom NTP background.
     *
     * Anomaly Investigation:
     * - `customBackground` is updated with this value from `HomePage.Models.SettingsModel` and `HomePage.Views.BackgroundPickerView`.
     * - Check the above places in code and make sure nothing got broken to cause the update to be fired repeatedly.
     */
    case newTabBackgroundSelectedSolidColor

    /**
     * Event Trigger: User selects illustration as custom NTP background.
     *
     * Anomaly Investigation:
     * - `customBackground` is updated with this value from `HomePage.Models.SettingsModel` and `HomePage.Views.BackgroundPickerView`.
     * - Check the above places in code and make sure nothing got broken to cause the update to be fired repeatedly.
     */
    case newTabBackgroundSelectedIllustration

    /**
     * Event Trigger: User removes custom NTP background.
     *
     * Anomaly Investigation:
     * - `customBackground` is updated with this value from `HomePage.Models.SettingsModel` and `HomePage.Views.SettingsView`.
     * - Check the above places in code and make sure nothing got broken to cause the update to be fired repeatedly.
     */
    case newTabBackgroundReset

    var name: String {
        switch self {
        case .newTabBackgroundSelectedGradient:
            return "m_mac_newtab_background_selected-gradient"
        case .newTabBackgroundSelectedSolidColor:
            return "m_mac_newtab_background_selected-solid-color"
        case .newTabBackgroundSelectedIllustration:
            return "m_mac_newtab_background_selected-illustration"
        case .newTabBackgroundReset:
            return "m_mac_newtab_background_reset"
        }
    }

    var parameters: [String: String]? {
        nil
    }

    var error: (any Error)? {
        nil
    }
}
