//
//  Logger+Multiple.swift
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
import os.log

extension Logger {
    static var dataImportExport = { Logger(subsystem: "Data Import/Export", category: "") }()
    static var config = { Logger(subsystem: "Configuration Downloading", category: "") }()
    static var autoLock = { Logger(subsystem: "Auto-Lock", category: "") }()
    static var httpsUpgrade = { Logger(subsystem: "HTTPS Upgrade", category: "") }()
    static var atb = { Logger(subsystem: "ATB", category: "") }()
    static var tabSnapshots = { Logger(subsystem: "Tab Snapshots", category: "") }()
    static var tabLazyLoading = { Logger(subsystem: "Lazy Loading", category: "") }()
    static var updates = { Logger(subsystem: "Updates", category: "") }()
    static var tabPreview = { Logger(subsystem: "Tab Preview", category: "") }()
    static var maliciousSiteProtection = { Logger(subsystem: "Malsite Protection", category: "") }()
}
