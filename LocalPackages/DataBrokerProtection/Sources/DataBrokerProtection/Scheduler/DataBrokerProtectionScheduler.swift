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

public enum DataBrokerProtectionSchedulerError: Error {
    case loginItemDoesNotHaveNecessaryPermissions
    case appInWrongDirectory
    case operationsInterrupted
}

@objc
public class DataBrokerProtectionSchedulerErrorCollection: NSObject, NSSecureCoding {
    /*
     This needs to be an NSObject (rather than a struct) so it can be represented in Objective C
     and confrom to NSSecureCoding for the IPC layer.
     */

    private enum NSSecureCodingKeys {
        static let oneTimeError = "oneTimeError"
        static let operationErrors = "operationErrors"
    }

    public let oneTimeError: Error?
    public let operationErrors: [Error]?

    public init(oneTimeError: Error? = nil, operationErrors: [Error]? = nil) {
        self.oneTimeError = oneTimeError
        self.operationErrors = operationErrors
        super.init()
    }

    // MARK: - NSSecureCoding

    public static var supportsSecureCoding: Bool {
        return true
    }

    public func encode(with coder: NSCoder) {
        coder.encode(oneTimeError, forKey: NSSecureCodingKeys.oneTimeError)
        coder.encode(operationErrors, forKey: NSSecureCodingKeys.operationErrors)
    }

    public required init?(coder: NSCoder) {
        oneTimeError = coder.decodeObject(of: NSError.self, forKey: NSSecureCodingKeys.oneTimeError)
        operationErrors = coder.decodeArrayOfObjects(ofClass: NSError.self, forKey: NSSecureCodingKeys.operationErrors)
    }
}

public protocol DataBrokerProtectionScheduler {

    var status: DataBrokerProtectionSchedulerStatus { get }
    var statusPublisher: Published<DataBrokerProtectionSchedulerStatus>.Publisher { get }

    func startScheduler(showWebView: Bool)
    func stopScheduler()

    func optOutAllBrokers(showWebView: Bool, completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?)
    func startManualScan(showWebView: Bool, completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?)
    func runQueuedOperations(showWebView: Bool, completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?)
    func runAllOperations(showWebView: Bool)

    /// Debug operations

    func getDebugMetadata(completion: @escaping (DBPBackgroundAgentMetadata?) -> Void)
}

extension DataBrokerProtectionScheduler {
    public func startScheduler() {
        startScheduler(showWebView: false)
    }

    public func runAllOperations() {
        runAllOperations(showWebView: false)
    }

    public func startManualScan() {
        startManualScan(showWebView: false, completion: nil)
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
    private let userNotificationService: DataBrokerProtectionUserNotificationService

    /// Ensures that only one scheduler operation is executed at the same time.
    ///
    private let schedulerDispatchQueue = DispatchQueue(label: "schedulerDispatchQueue", qos: .background)

    @Published public var status: DataBrokerProtectionSchedulerStatus = .stopped

    public var statusPublisher: Published<DataBrokerProtectionSchedulerStatus>.Publisher { $status }

    private var lastSchedulerSessionStartTimestamp: Date?

    private lazy var dataBrokerProcessor: DataBrokerProtectionProcessor = {

        let runnerProvider = DataBrokerOperationRunnerProvider(privacyConfigManager: privacyConfigManager,
                                                               contentScopeProperties: contentScopeProperties,
                                                               emailService: emailService,
                                                               captchaService: captchaService)

        return DataBrokerProtectionProcessor(database: dataManager.database,
                                             config: DataBrokerProtectionSchedulerConfig(),
                                             operationRunnerProvider: runnerProvider,
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
            self.lastSchedulerSessionStartTimestamp = Date()
            self.status = .running
            os_log("Scheduler running...", log: .dataBrokerProtection)
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
        }
    }

    public func runQueuedOperations(showWebView: Bool = false,
                                    completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)? = nil) {
        os_log("Running queued operations...", log: .dataBrokerProtection)
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
        })

    }

    public func startManualScan(showWebView: Bool = false,
                                completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)? = nil) {
        let startTime = Date()
        stopScheduler()

        userNotificationService.requestNotificationPermission()

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
                    case DataBrokerProtectionSchedulerError.operationsInterrupted:
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

            fireManualScanCompletionPixel(startTime: startTime)
            completion?(errors)
        }
    }

    private func fireManualScanCompletionPixel(startTime: Date) {
        do {
            let profile = try dataManager.forceFetchProfile()

            if let profile = profile {
                let durationSinceStart = Date().timeIntervalSince(startTime) * 1000
                self.pixelHandler.fire(.initialScanTotalDuration(duration: durationSinceStart.rounded(.towardZero),
                                                                 profileQueries: profile.profileQueries.count))
            }
        } catch {
            os_log("Manual Scan Error when trying to fetch the profile to get the profile queries", log: .dataBrokerProtection)
        }
    }

    public func optOutAllBrokers(showWebView: Bool = false,
                                 completion: ((DataBrokerProtectionSchedulerErrorCollection?) -> Void)?) {
        os_log("Opting out all brokers...", log: .dataBrokerProtection)
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

            completion?(errors)
        })
    }

    public func getDebugMetadata(completion: (DBPBackgroundAgentMetadata?) -> Void) {
        if let backgroundAgentVersion = Bundle.main.releaseVersionNumber, let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            completion(DBPBackgroundAgentMetadata(backgroundAgentVersion: backgroundAgentVersion + " (build: \(buildNumber))",
                                                  isAgentRunning: status == .running,
                                                  agentSchedulerState: status.toString,
                                                  lastSchedulerSessionStartTimestamp: lastSchedulerSessionStartTimestamp?.timeIntervalSince1970))
        } else {
            completion(DBPBackgroundAgentMetadata(backgroundAgentVersion: "ERROR: Error fetching background agent version",
                                                  isAgentRunning: status == .running,
                                                  agentSchedulerState: status.toString,
                                                  lastSchedulerSessionStartTimestamp: lastSchedulerSessionStartTimestamp?.timeIntervalSince1970))
        }
    }
}

extension DataBrokerProtectionSchedulerStatus {
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
