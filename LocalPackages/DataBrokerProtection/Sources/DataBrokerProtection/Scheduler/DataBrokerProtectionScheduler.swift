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

public final class DefaultDataBrokerProtectionScheduler {

    private enum SchedulerCycle {
        // Arbitrary numbers for now

        static let interval: TimeInterval = 40 * 60 // 40 minutes
        static let tolerance: TimeInterval = 20 * 60 // 20 minutes
    }

    private enum DataBrokerProtectionCurrentOperation {
        case idle
        case queued
        case manualScan
        case optOutAll
        case all
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
    private let userNotificationService: DataBrokerProtectionUserNotificationService
    private var currentOperation: DataBrokerProtectionCurrentOperation = .idle

    /// Ensures that only one scheduler operation is executed at the same time.
    ///
    private let schedulerDispatchQueue = DispatchQueue(label: "schedulerDispatchQueue", qos: .background)

    @Published public var status: DataBrokerProtectionSchedulerStatus = .stopped

    public var statusPublisher: Published<DataBrokerProtectionSchedulerStatus>.Publisher { $status }

    public var lastSchedulerSessionStartTimestamp: Date?

    private lazy var dataBrokerProcessor: DataBrokerProtectionProcessor = {

        let runnerProvider = DataBrokerJobRunnerProvider(privacyConfigManager: privacyConfigManager,
                                                               contentScopeProperties: contentScopeProperties,
                                                               emailService: emailService,
                                                               captchaService: captchaService)

        return DataBrokerProtectionProcessor(database: dataManager.database,
                                             jobRunnerProvider: runnerProvider,
                                             notificationCenter: notificationCenter,
                                             pixelHandler: pixelHandler,
                                             userNotificationService: userNotificationService)
    }()

    public init(privacyConfigManager: PrivacyConfigurationManaging,
                contentScopeProperties: ContentScopeProperties,
                dataManager: DataBrokerProtectionDataManager,
                notificationCenter: NotificationCenter = NotificationCenter.default,
                pixelHandler: EventMapping<DataBrokerProtectionPixels>,
                redeemUseCase: DataBrokerProtectionRedeemUseCase,
                userNotificationService: DataBrokerProtectionUserNotificationService
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
        self.userNotificationService = userNotificationService

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

            guard self.currentOperation != .manualScan else {
                os_log("Manual scan in progress, returning...", log: .dataBrokerProtection)
                completion(.finished)
                return
            }
            self.lastSchedulerSessionStartTimestamp = Date()
            self.status = .running
            os_log("Scheduler running...", log: .dataBrokerProtection)
            self.currentOperation = .queued
            self.dataBrokerProcessor.runQueuedOperations(showWebView: showWebView) { [weak self] errors in
                if let errors = errors {
                    if let oneTimeError = errors.oneTimeError {
                        os_log("Error during startScheduler in dataBrokerProcessor.runQueuedOperations(), error: %{public}@", log: .dataBrokerProtection, oneTimeError.localizedDescription)
                        self?.pixelHandler.fire(.generalError(error: oneTimeError, functionOccurredIn: "DefaultDataBrokerProtectionScheduler.startScheduler"))
                    }
                    if let operationErrors = errors.operationErrors,
                              operationErrors.count != 0 {
                        os_log("Operation error(s) during startScheduler in dataBrokerProcessor.runQueuedOperations(), count: %{public}d", log: .dataBrokerProtection, operationErrors.count)
                    }
                }
                self?.status = .idle
                self?.currentOperation = .idle
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
        guard self.currentOperation != .manualScan else {
            os_log("Manual scan in progress, returning...", log: .dataBrokerProtection)
            return
        }

        os_log("Running all operations...", log: .dataBrokerProtection)
        self.currentOperation = .all
        self.dataBrokerProcessor.runAllOperations(showWebView: showWebView) { [weak self] errors in
            if let errors = errors {
                if let oneTimeError = errors.oneTimeError {
                    os_log("Error during DefaultDataBrokerProtectionScheduler.runAllOperations in dataBrokerProcessor.runAllOperations(), error: %{public}@", log: .dataBrokerProtection, oneTimeError.localizedDescription)
                    self?.pixelHandler.fire(.generalError(error: oneTimeError, functionOccurredIn: "DefaultDataBrokerProtectionScheduler.runAllOperations"))
                }
                if let operationErrors = errors.operationErrors,
                          operationErrors.count != 0 {
                    os_log("Operation error(s) during DefaultDataBrokerProtectionScheduler.runAllOperations in dataBrokerProcessor.runAllOperations(), count: %{public}d", log: .dataBrokerProtection, operationErrors.count)
                }
            }
            self?.currentOperation = .idle
        }
    }

    public func runQueuedOperations(showWebView: Bool = false,
                                    completion: ((DataBrokerProtectionAgentErrorCollection?) -> Void)? = nil) {
        guard self.currentOperation != .manualScan else {
            os_log("Manual scan in progress, returning...", log: .dataBrokerProtection)
            return
        }

        os_log("Running queued operations...", log: .dataBrokerProtection)
        self.currentOperation = .queued
        dataBrokerProcessor.runQueuedOperations(showWebView: showWebView,
                                                completion: { [weak self] errors in
            if let errors = errors {
                if let oneTimeError = errors.oneTimeError {
                    os_log("Error during DefaultDataBrokerProtectionScheduler.runQueuedOperations in dataBrokerProcessor.runQueuedOperations(), error: %{public}@", log: .dataBrokerProtection, oneTimeError.localizedDescription)
                    self?.pixelHandler.fire(.generalError(error: oneTimeError, functionOccurredIn: "DefaultDataBrokerProtectionScheduler.runQueuedOperations"))
                }
                if let operationErrors = errors.operationErrors,
                          operationErrors.count != 0 {
                    os_log("Operation error(s) during DefaultDataBrokerProtectionScheduler.runQueuedOperations in dataBrokerProcessor.runQueuedOperations(), count: %{public}d", log: .dataBrokerProtection, operationErrors.count)
                }
            }
            completion?(errors)
            self?.currentOperation = .idle
        })

    }

    public func startManualScan(showWebView: Bool = false,
                                startTime: Date,
                                completion: ((DataBrokerProtectionAgentErrorCollection?) -> Void)? = nil) {
        pixelHandler.fire(.initialScanPreStartDuration(duration: (Date().timeIntervalSince(startTime) * 1000).rounded(.towardZero)))
        let backgroundAgentManualScanStartTime = Date()
        stopScheduler()

        userNotificationService.requestNotificationPermission()
        self.currentOperation = .manualScan
        os_log("Scanning all brokers...", log: .dataBrokerProtection)
        dataBrokerProcessor.startManualScans(showWebView: showWebView) { [weak self] errors in
            guard let self = self else { return }

            self.startScheduler(showWebView: showWebView)

            if errors?.oneTimeError == nil {
                self.userNotificationService.sendFirstScanCompletedNotification()
            }

            if let hasMatches = try? self.dataManager.hasMatches(),
                hasMatches {
                self.userNotificationService.scheduleCheckInNotificationIfPossible()
            }

            if let errors = errors {
                if let oneTimeError = errors.oneTimeError {
                    switch oneTimeError {
                    case DataBrokerProtectionAgentInterfaceError.operationsInterrupted:
                        os_log("Interrupted during DefaultDataBrokerProtectionScheduler.startManualScan in dataBrokerProcessor.runAllScanOperations(), error: %{public}@", log: .dataBrokerProtection, oneTimeError.localizedDescription)
                    default:
                        os_log("Error during DefaultDataBrokerProtectionScheduler.startManualScan in dataBrokerProcessor.runAllScanOperations(), error: %{public}@", log: .dataBrokerProtection, oneTimeError.localizedDescription)
                        self.pixelHandler.fire(.generalError(error: oneTimeError, functionOccurredIn: "DefaultDataBrokerProtectionScheduler.startManualScan"))
                    }
                }
                if let operationErrors = errors.operationErrors,
                          operationErrors.count != 0 {
                    os_log("Operation error(s) during DefaultDataBrokerProtectionScheduler.startManualScan in dataBrokerProcessor.runAllScanOperations(), count: %{public}d", log: .dataBrokerProtection, operationErrors.count)
                }
            }
            self.currentOperation = .idle
            fireManualScanCompletionPixel(startTime: backgroundAgentManualScanStartTime)
            completion?(errors)
        }
    }

    private func fireManualScanCompletionPixel(startTime: Date) {
        do {
            let profileQueries = try dataManager.profileQueriesCount()
            let durationSinceStart = Date().timeIntervalSince(startTime) * 1000
            self.pixelHandler.fire(.initialScanTotalDuration(duration: durationSinceStart.rounded(.towardZero),
                                                             profileQueries: profileQueries))
        } catch {
            os_log("Manual Scan Error when trying to fetch the profile to get the profile queries", log: .dataBrokerProtection)
        }
    }

    public func optOutAllBrokers(showWebView: Bool = false,
                                 completion: ((DataBrokerProtectionAgentErrorCollection?) -> Void)?) {

        guard self.currentOperation != .manualScan else {
            os_log("Manual scan in progress, returning...", log: .dataBrokerProtection)
            return
        }

        os_log("Opting out all brokers...", log: .dataBrokerProtection)
        self.currentOperation = .optOutAll
        self.dataBrokerProcessor.runAllOptOutOperations(showWebView: showWebView,
                                                        completion: { [weak self] errors in
            if let errors = errors {
                if let oneTimeError = errors.oneTimeError {
                    os_log("Error during DefaultDataBrokerProtectionScheduler.optOutAllBrokers in dataBrokerProcessor.runAllOptOutOperations(), error: %{public}@", log: .dataBrokerProtection, oneTimeError.localizedDescription)
                    self?.pixelHandler.fire(.generalError(error: oneTimeError, functionOccurredIn: "DefaultDataBrokerProtectionScheduler.optOutAllBrokers"))
                }
                if let operationErrors = errors.operationErrors,
                          operationErrors.count != 0 {
                    os_log("Operation error(s) during DefaultDataBrokerProtectionScheduler.optOutAllBrokers in dataBrokerProcessor.runAllOptOutOperations(), count: %{public}d", log: .dataBrokerProtection, operationErrors.count)
                }
            }
            self?.currentOperation = .idle
            completion?(errors)
        })
    }
}

public extension DataBrokerProtectionSchedulerStatus {
    var toString: String {
        switch self {
        case .idle:
            return "idle"
        case .running:
            return "running"
        case .stopped:
            return "stopped"
        }
    }
}
