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
import Combine

public enum DataBrokerProtectionSchedulerStatus: Codable {
    case stopped
    case idle
    case running
}

public protocol DataBrokerProtectionScheduler {

    var status: DataBrokerProtectionSchedulerStatus { get }
    var statusPublisher: Published<DataBrokerProtectionSchedulerStatus>.Publisher { get }

    func startScheduler(showWebView: Bool)
    func stopScheduler()

    func optOutAllBrokers(showWebView: Bool, completion: (() -> Void)?)
    func scanAllBrokers(showWebView: Bool, completion: (() -> Void)?)
    func runQueuedOperations(showWebView: Bool, completion: (() -> Void)?)
    func runAllOperations(showWebView: Bool)
}

extension DataBrokerProtectionScheduler {
    public func startScheduler() {
        startScheduler(showWebView: false)
    }

    public func runAllOperations() {
        runAllOperations(showWebView: false)
    }

    public func scanAllBrokers() {
        scanAllBrokers(showWebView: false, completion: nil)
    }
}

public final class DefaultDataBrokerProtectionScheduler: DataBrokerProtectionScheduler {

    private enum SchedulerCycle {
        // Arbitrary numbers for now

        static let interval: TimeInterval = 40 * 60 // 40 minutes
        static let tolerance: TimeInterval = 20 * 60 // 20 minutes
    }

    private let privacyConfigManager: PrivacyConfigurationManaging
    private let contentScopeProperties: ContentScopeProperties
    private let dataManager: DataBrokerProtectionDataManager
    private let activity: NSBackgroundActivityScheduler
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let schedulerIdentifier = "com.duckduckgo.macos.browser.databroker-protection-scheduler"
    private let notificationCenter: NotificationCenter
    private let emailService: EmailServiceProtocol
    private let captchaService: CaptchaServiceProtocol

    @Published public var status: DataBrokerProtectionSchedulerStatus = .stopped

    public var statusPublisher: Published<DataBrokerProtectionSchedulerStatus>.Publisher { $status }

    private lazy var dataBrokerProcessor: DataBrokerProtectionProcessor = {

        let runnerProvider = DataBrokerOperationRunnerProvider(privacyConfigManager: privacyConfigManager,
                                                               contentScopeProperties: contentScopeProperties,
                                                               emailService: emailService,
                                                               captchaService: captchaService)

        return DataBrokerProtectionProcessor(database: dataManager.database,
                                             config: DataBrokerProtectionSchedulerConfig(),
                                             operationRunnerProvider: runnerProvider,
                                             notificationCenter: notificationCenter,
                                             pixelHandler: pixelHandler)
    }()

    public init(privacyConfigManager: PrivacyConfigurationManaging,
                contentScopeProperties: ContentScopeProperties,
                dataManager: DataBrokerProtectionDataManager,
                notificationCenter: NotificationCenter = NotificationCenter.default,
                pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                redeemUseCase: DataBrokerProtectionRedeemUseCase
    ) {

        activity = NSBackgroundActivityScheduler(identifier: schedulerIdentifier)
        activity.repeats = true
        activity.interval = SchedulerCycle.interval
        activity.tolerance = SchedulerCycle.tolerance
        activity.qualityOfService = QualityOfService.default

        self.dataManager = dataManager
        self.privacyConfigManager = privacyConfigManager
        self.contentScopeProperties = contentScopeProperties
        self.pixelHandler = pixelHandler
        self.notificationCenter = notificationCenter

        self.emailService = EmailService(redeemUseCase: redeemUseCase)
        self.captchaService = CaptchaService(redeemUseCase: redeemUseCase)
    }

    public func startScheduler(showWebView: Bool = false) {
        guard status == .stopped else {
            os_log("Trying to start scheduler when it's already running, returning...", log: .dataBrokerProtection)
            return
        }

        status = .idle
        activity.schedule { completion in
            guard self.status != .stopped else {
                os_log("Activity started when scheduler was already running, returning...", log: .dataBrokerProtection)
                completion(.finished)
                return
            }
            self.status = .running
            os_log("Scheduler running...", log: .dataBrokerProtection)
            self.dataBrokerProcessor.runQueuedOperations(showWebView: showWebView) { [weak self] in
                self?.status = .idle
                completion(.finished)
            }
        }
    }

    public func stopScheduler() {
        os_log("Stopping scheduler...", log: .dataBrokerProtection)
        activity.invalidate()
        status = .stopped
        dataBrokerProcessor.stopAllOperations()
    }

    public func runAllOperations(showWebView: Bool = false) {
        os_log("Running all operations...", log: .dataBrokerProtection)
        self.dataBrokerProcessor.runAllOperations(showWebView: showWebView)
    }

    public func runQueuedOperations(showWebView: Bool = false, completion: (() -> Void)? = nil) {
        os_log("Running queued operations...", log: .dataBrokerProtection)
        dataBrokerProcessor.runQueuedOperations(showWebView: showWebView,
                                                completion: completion)

    }

    public func scanAllBrokers(showWebView: Bool = false, completion: (() -> Void)? = nil) {
        os_log("Scanning all brokers...", log: .dataBrokerProtection)
        self.dataBrokerProcessor.runAllScanOperations(showWebView: showWebView,
                                                      completion: completion)
    }

    public func optOutAllBrokers(showWebView: Bool = false, completion: (() -> Void)?) {
        os_log("Opting out all brokers...", log: .dataBrokerProtection)
        self.dataBrokerProcessor.runAllOptOutOperations(showWebView: showWebView,
                                                        completion: completion)
    }
}
