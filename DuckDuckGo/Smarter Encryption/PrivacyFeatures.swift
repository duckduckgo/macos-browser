//
//  PrivacyFeatures.swift
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

import BrowserServicesKit

protocol PrivacyFeaturesProtocol {
    var contentBlocking: AnyContentBlocking { get }

    var httpsUpgradeStore: any HTTPSUpgradeStore { get }
    var httpsUpgrade: HTTPSUpgrade { get }
}
typealias AnyPrivacyFeatures = any PrivacyFeaturesProtocol

// kill me plz!!!
var PrivacyFeatures: AnyPrivacyFeatures {
    AppPrivacyFeatures.shared
}

final class AppPrivacyFeatures: PrivacyFeaturesProtocol {
    static var shared: AnyPrivacyFeatures!

    let contentBlocking: AnyContentBlocking
    let httpsUpgradeStore: any HTTPSUpgradeStore
    let httpsUpgrade: HTTPSUpgrade

    init(contentBlocking: AnyContentBlocking, httpsUpgradeStore: HTTPSUpgradeStore) {
        self.contentBlocking = contentBlocking
        self.httpsUpgradeStore = httpsUpgradeStore
        self.httpsUpgrade = HTTPSUpgrade(store: httpsUpgradeStore, privacyManager: contentBlocking.privacyConfigurationManager)
    }

}
