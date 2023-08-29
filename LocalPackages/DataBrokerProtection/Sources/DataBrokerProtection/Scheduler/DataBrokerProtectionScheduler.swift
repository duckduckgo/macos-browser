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
    enum Status {
        case stopped
        case idle
        case running
    }

    private enum SchedulerCycle {
        // Arbitrary numbers for now

        static let interval: TimeInterval = 5 * 60 // 5 minutes
        static let tolerance: TimeInterval = 60 // 1 minute
    }

    private let privacyConfigManager: PrivacyConfigurationManaging
    private let contentScopeProperties: ContentScopeProperties
    private let dataManager: DataBrokerProtectionDataManager
    private let activity: NSBackgroundActivityScheduler
    private let errorHandler: EventMapping<DataBrokerProtectionOperationError>
    private let schedulerIdentifier = "com.duckduckgo.macos.browser.databroker-protection-scheduler"
    private let notificationCenter: NotificationCenter
    private let emailService: EmailServiceProtocol
    private let captchaService: CaptchaServiceProtocol
    @Published var status: Status = .stopped

    lazy var dataBrokerProcessor: DataBrokerProtectionProcessor = {

        let runnerProvider = DataBrokerOperationRunnerProvider(privacyConfigManager: privacyConfigManager,
                                                               contentScopeProperties: contentScopeProperties,
                                                               emailService: emailService,
                                                               captchaService: captchaService)

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
                errorHandler: EventMapping<DataBrokerProtectionOperationError>,
                redeemUseCase: DataBrokerProtectionRedeemUseCase
    ) {

        activity = NSBackgroundActivityScheduler(identifier: schedulerIdentifier)
        activity.repeats = true
        activity.interval = SchedulerCycle.interval
        activity.tolerance = SchedulerCycle.tolerance
        activity.qualityOfService = QualityOfService.utility

        self.dataManager = dataManager
        self.privacyConfigManager = privacyConfigManager
        self.contentScopeProperties = contentScopeProperties
        self.errorHandler = errorHandler
        self.notificationCenter = notificationCenter

        self.emailService = EmailService(redeemUseCase: redeemUseCase)
        self.captchaService = CaptchaService(redeemUseCase: redeemUseCase)
    }

    public func start(debug: Bool = true) {
        os_log("Starting scheduler...", log: .dataBrokerProtection)
        if debug {
            self.status = .running
            self.dataBrokerProcessor.runQueuedOperations {  [weak self] in
                self?.status = .idle
            }
        } else {
            activity.schedule { completion in
                self.status = .running
                os_log("Scheduler running...", log: .dataBrokerProtection)
                self.dataBrokerProcessor.runQueuedOperations { [weak self] in
                    self?.status = .idle
                    completion(.finished)
                }
            }
        }
    }

    public func stop() {
        os_log("Stopping scheduler...", log: .dataBrokerProtection)
        activity.invalidate()
        status = .stopped
    }

    public func scanAllBrokers(completion: (() -> Void)? = nil) {
        os_log("Scanning all brokers...", log: .dataBrokerProtection)
        self.dataBrokerProcessor.runScanOnAllDataBrokers(completion: completion)
    }

}
