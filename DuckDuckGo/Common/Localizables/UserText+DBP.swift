//
//  UserText+DBP.swift
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
import Common

// MARK: - DBP Error pages
extension UserText {
    static let dbpErrorPageBadPathTitle = NSLocalizedString("dbp.errorpage.bad.path.title", value: "Move DuckDuckGo App to Applications", comment: "Title for Personal Information Removal bad path error screen")
    static let dbpErrorPageBadPathMessage = NSLocalizedString("dbp.errorpage.bad.path.message", value: "To use Personal Information Removal, the DuckDuckGo app needs to be in the Applications folder on your Mac. You can move the app yourself and restart the browser, or we can do it for you.", comment: "Message for Personal Information Removal bad path error screen")
    static let dbpErrorPageBadPathCTA = NSLocalizedString("dbp.errorpage.bad.path.cta", value: "Move App for Me...", comment: "Call to action for moving the app to the Applications folder")

    static let dbpErrorPageNoPermissionTitle = NSLocalizedString("dbp.errorpage.no.permission.title", value: "Change System Setting", comment: "Title for error screen when there is no permission")
    static let dbpErrorPageNoPermissionMessage = NSLocalizedString("dbp.errorpage.no.permission.message", value: "Open System Settings and allow DuckDuckGo Personal Information Removal to run in the background.", comment: "Message for error screen when there is no permission")
    static let dbpErrorPageNoPermissionCTA = NSLocalizedString("dbp.errorpage.no.permission.cta", value: "Open System Settings...", comment: "Call to action for opening system settings")
}
