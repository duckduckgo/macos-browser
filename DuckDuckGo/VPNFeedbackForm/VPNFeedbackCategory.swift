//
//  VPNFeedbackCategory.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

#if NETWORK_PROTECTION

enum VPNFeedbackCategory: String, CaseIterable {
    case landingPage
    case unableToInstall
    case failsToConnect
    case tooSlow
    case issueWithAppOrWebsite
    case cantConnectToLocalDevice
    case appCrashesOrFreezes
    case featureRequest
    case somethingElse

    var isFeedbackCategory: Bool {
        switch self {
        case .landingPage:
            return false
        case .unableToInstall,
                .failsToConnect,
                .tooSlow,
                .issueWithAppOrWebsite,
                .cantConnectToLocalDevice,
                .appCrashesOrFreezes,
                .featureRequest,
                .somethingElse:
            return true
        }
    }

    var displayName: String {
        switch self {
        case .landingPage: return "What's happening?"
        case .unableToInstall: return "Unable to install VPN"
        case .failsToConnect: return "VPN fails to connect"
        case .tooSlow: return "VPN connection is too slow"
        case .issueWithAppOrWebsite: return "Issue with other apps or websites"
        case .cantConnectToLocalDevice: return "Can't connect to local device"
        case .appCrashesOrFreezes: return "Browser crashes or freezes"
        case .featureRequest: return "Feature request"
        case .somethingElse: return "Something else"
        }
    }
}

#endif
