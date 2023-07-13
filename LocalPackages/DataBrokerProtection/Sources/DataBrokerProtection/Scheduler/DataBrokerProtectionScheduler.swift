//
//  DataBrokerProtectionScheduler.swift
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
import Common
import BrowserServicesKit

public final class DataBrokerProtectionScheduler {
    private let privacyConfigManager: PrivacyConfigurationManaging
    private let contentScopeProperties: ContentScopeProperties
    private let dataManager: DataBrokerProtectionDataManager
    private let activity: NSBackgroundActivityScheduler
    private let errorHandler: EventMapping<DataBrokerProtectionOperationError>
    private let schedulerIdentifier = "com.duckduckgo.macos.browser.databroker-protection-scheduler"
    private let notificationCenter: NotificationCenter

    lazy var dataBrokerProcessor: DataBrokerProtectionProcessor = {

        let runnerProvider = DataBrokerOperationRunnerProvider(privacyConfigManager: privacyConfigManager,
                                                               contentScopeProperties: contentScopeProperties)

        return DataBrokerProtectionProcessor(database: dataManager.database,
                                             config: DataBrokerProtectionSchedulerConfig(),
                                             operationRunnerProvider: runnerProvider,
                                             notificationCenter: notificationCenter,
                                             errorHandler: errorHandler)
    }()

    public init(privacyConfigManager: PrivacyConfigurationManaging,
                contentScopeProperties: ContentScopeProperties,
                dataManager: DataBrokerProtectionDataManager,
                notificationCenter: NotificationCenter = NotificationCenter.default,
                errorHandler: EventMapping<DataBrokerProtectionOperationError>) {

        activity = NSBackgroundActivityScheduler(identifier: schedulerIdentifier)
        activity.repeats = true
        // TODO: Arbitrary numbers for now
        // Scheduling an activity to fire between 15 and 45 minutes from now
        activity.interval = 30 * 60
        activity.tolerance = 15 * 60

        activity.qualityOfService = QualityOfService.utility

        self.dataManager = dataManager
        self.privacyConfigManager = privacyConfigManager
        self.contentScopeProperties = contentScopeProperties
        self.errorHandler = errorHandler
        self.notificationCenter = notificationCenter
    }

    public func start() {
        os_log("Starting scheduler...", log: .dataBrokerProtection)
      //  activity.schedule { completion in
            os_log("Scheduler runnning...", log: .dataBrokerProtection)
            self.dataBrokerProcessor.runQueuedOperations {
             //   completion(.finished)
            }
      //  }
    }

    public func stop() {
        os_log("Stopping scheduler...", log: .dataBrokerProtection)
        activity.invalidate()
    }

    public func scanAllBrokers() {
        os_log("Scanning all brokers...", log: .dataBrokerProtection)
        self.dataBrokerProcessor.runScanOnAllDataBrokers()
    }

}
