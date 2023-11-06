//
//  NetworkProtectionUserDefaultsConstants.swift
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

/// Constants representing default values for NetP settings to be both accessible from Controller and Main Menu
enum NetworkProtectionUserDefaultsConstants {

    static let onDemandActivation = true
    static let shouldConnectOnLogIn = false
    static let shouldEnforceRoutes = false
    static let shouldIncludeAllNetworks = false
    static let shouldExcludeLocalNetworks = false
    static let isConnectionTesterEnabled = true

}
