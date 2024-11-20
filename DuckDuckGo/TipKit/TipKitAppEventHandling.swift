//
//  TipKitAppEventHandling.swift
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
import BrowserServicesKit
import os.log
import TipKit

protocol TipKitAppEventHandling {
    func appDidFinishLaunching()
}

struct TipKitAppEventHandler: TipKitAppEventHandling {

    private let controller: TipKitController
    private let featureFlagger: FeatureFlagger
    private let logger: Logger

    init(controller: TipKitController = .make(),
         featureFlagger: FeatureFlagger,
         logger: Logger = .tipKit) {

        self.controller = controller
        self.featureFlagger = featureFlagger
        self.logger = logger
    }

    func appDidFinishLaunching() {
        guard featureFlagger.isFeatureOn(.networkProtectionUserTips) else {
            logger.log("TipKit disabled by remote feature flag.")
            return
        }

        if #available(macOS 14.0, *) {
            typealias DataStoreLocation = Tips.ConfigurationOption.DatastoreLocation

            /// A this time TipKit does not seem to handle synchronization of state between multiple apps very well.
            /// That said, we still use the app configuration group for the data store in hopes this will soon change.
            /// As long as we don't use TipKit for the same views from multiple Apps we'll be fine, but we can test
            /// whether it's still broken rather easily if we keep the state in a shared app group, and we avoid having
            /// to migrate the store in the future.
            let appConfigurationGroupIdentifier = Bundle.main.appGroup(bundle: .appConfiguration)

            guard let dataStoreLocation = try? DataStoreLocation.groupContainer(identifier: appConfigurationGroupIdentifier) else {
                fatalError()
            }

            controller.configureTipKit([
                .displayFrequency(.immediate),
                .datastoreLocation(dataStoreLocation)
            ])
        } else {
            logger.log("TipKit initialization skipped: iOS 17.0 or later is required.")
        }
    }
}
