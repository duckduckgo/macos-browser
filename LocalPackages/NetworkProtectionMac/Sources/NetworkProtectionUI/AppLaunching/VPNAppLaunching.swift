//
//  VPNAppLaunching.swift
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

// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Foundation

public enum VPNAppLaunchCommand: Codable {
    case justOpen
    case shareFeedback
    case showFAQ
    case showStatus
    case showSettings
    case showVPNLocations
    case startVPN
    case stopVPN
    case enableOnDemand
    case moveAppToApplications
    case showPrivacyPro
}

public protocol VPNAppLaunching {
    func launchApp(withCommand command: VPNAppLaunchCommand) async
}
