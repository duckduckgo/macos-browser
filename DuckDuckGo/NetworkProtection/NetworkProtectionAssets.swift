//
//  NetworkProtectionAssets.swift
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

enum NetworkProtectionAsset: String {
    case ipAddressIcon = "IP-16"
    case serverLocationIcon = "Server-Location-16"
    case vpnDisabledImage = "VPN-Disabled-128"
    case vpnEnabledImage = "VPN-128"
    case vpnIcon = "VPN-16"
    case vpnIssueIcon = "VPN-Issue-16"
}
