//
//  NonStandardPixel.swift
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
import BrowserServicesKit
import DDGSync
import Configuration

/// These pixels deliberately omit the `m_mac_` prefix in order to format these pixel the same way as other platforms, they are sent unchanged
enum NonStandardPixel: PixelKitEventV2 {

    case brokenSiteReport
    case brokenSiteReportShown
    case brokenSiteReportSent
    case privacyDashboardReportBrokenSite
    case emailEnabled
    case emailDisabled
    case emailUserPressedUseAddress
    case emailUserPressedUseAlias
    case emailUserCreatedAlias

    var name: String {
        switch self {
        case .brokenSiteReport: return "epbf_macos_desktop"
        case .brokenSiteReportSent: return "m_report-broken-site_sent"
        case .brokenSiteReportShown: return "m_report-broken-site_shown"
        case .privacyDashboardReportBrokenSite: return "mp_rb"
        case .emailEnabled: return "email_enabled_macos_desktop"
        case .emailDisabled: return "email_disabled_macos_desktop"
        case .emailUserPressedUseAddress: return "email_filled_main_macos_desktop"
        case .emailUserPressedUseAlias: return "email_filled_random_macos_desktop"
        case .emailUserCreatedAlias: return "email_generated_button_macos_desktop"
        }
    }

    var parameters: [String: String]? {
        return nil
    }

    var error: Error? {
        return nil
    }
}
