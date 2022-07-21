//
//  WebsiteBreakage.swift
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

struct WebsiteBreakage {

    enum Category: String, CaseIterable {
        case cantSignIn = "login"
        case contentIsMissing = "content"
        case linksDontWork = "links"
        case browserIsIncompatible = "unsupported"
        case theSiteAskedToDisable = "paywall"
        case videoOrImagesDidntLoad = "images"
        case cookiePromptNotManaged = "cookieprompt"
        case somethingElse = "other"
    }

    let category: Category?
    let description: String?
    let siteUrlString: String
    let osVersion: String
    let upgradedHttps: Bool
    let tdsETag: String?
    let blockedTrackerDomains: [String]
    let installedSurrogates: [String]
    let isGPCEnabled: Bool
    let ampURL: String
    let urlParametersRemoved: Bool
    let manufacturer: String

    init(
        category: Category?,
        description: String?,
        siteUrlString: String,
        osVersion: String,
        upgradedHttps: Bool,
        tdsETag: String?,
        blockedTrackerDomains: [String],
        installedSurrogates: [String],
        isGPCEnabled: Bool,
        ampURL: String,
        urlParametersRemoved: Bool,
        manufacturer: String = "Apple"
    ) {
        self.category = category
        self.description = description
        self.siteUrlString = siteUrlString
        self.osVersion = osVersion
        self.upgradedHttps = upgradedHttps
        self.tdsETag = tdsETag
        self.blockedTrackerDomains = blockedTrackerDomains
        self.installedSurrogates = installedSurrogates
        self.isGPCEnabled = isGPCEnabled
        self.ampURL = ampURL
        self.urlParametersRemoved = urlParametersRemoved
        self.manufacturer = manufacturer
    }

    var requestParameters: [String: String] {
        [
            "category": category?.rawValue ?? "",
            "description": description ?? "",
            "siteUrl": siteUrlString,
            "upgradedHttps": upgradedHttps ? "true" : "false",
            "tds": tdsETag?.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) ?? "",
            "blockedTrackers": blockedTrackerDomains.joined(separator: ","),
            "surrogates": installedSurrogates.joined(separator: ","),
            "gpc": isGPCEnabled ? "true" : "false",
            "ampUrl": ampURL,
            "urlParametersRemoved": urlParametersRemoved ? "true" : "false",
            "os": osVersion,
            "manufacturer": manufacturer,
            "reportFlow": "native"
        ]
    }
}
