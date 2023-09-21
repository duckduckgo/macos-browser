//
//  ResultsViewModel.swift
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
import SwiftUI

final class ResultsViewModel: ObservableObject {
    private let dataManager: DataBrokerProtectionDataManaging
    private let notificationCenter: NotificationCenter

    struct RemovedProfile: Identifiable {
        let id = UUID()
        let dataBroker: String
        let scheduledDate: Date?

        var formattedDate: String {
            if let date = scheduledDate {
                let formatter = DateFormatter()
                formatter.timeStyle = .none
                formatter.dateStyle = .short
                return formatter.string(from: date)
            } else {
                return "No date set"
            }
        }
    }

    struct PendingProfile: Identifiable {
        let id = UUID()
        let dataBroker: String
        let profile: String
        let addresses: [String]
        let age: String?
        let relatives: [String]
        let error: String?
        let errorDescription: String?
        let operationData: OptOutOperationData
        var hasError: Bool {
            error != nil
        }

        var profileWithAge: String {
            if let age = age, !age.isEmpty {
                return "\(profile) (\(age))"
            }
            return profile
        }
    }

    @Published var removedProfiles =  [RemovedProfile]()
    @Published var pendingProfiles = [PendingProfile]()
    @Published var isLoading = false
    @Published var headerStatusText = ""

    init(dataManager: DataBrokerProtectionDataManaging,
         notificationCenter: NotificationCenter = .default) {
        self.dataManager = dataManager
        self.notificationCenter = notificationCenter

        updateUI(ignoresCache: false)
        setupNotifications()
    }

    private func setupNotifications() {
        notificationCenter.addObserver(self,
                                       selector: #selector(reloadData),
                                       name: DataBrokerProtectionNotifications.didFinishScan,
                                       object: nil)

        notificationCenter.addObserver(self,
                                       selector: #selector(reloadData),
                                       name: DataBrokerProtectionNotifications.didFinishOptOut,
                                       object: nil)
    }

    // swiftlint:disable:next function_body_length
    private func updateUI(ignoresCache: Bool) {
        isLoading = true
        Task {
            let startTime = DispatchTime.now().uptimeNanoseconds
            let brokersInfoData = await dataManager.fetchBrokerProfileQueryData(ignoresCache: ignoresCache)
            let endTime = DispatchTime.now().uptimeNanoseconds

            DispatchQueue.main.async {
                var removedProfiles = [RemovedProfile]()
                var pendingProfiles = [PendingProfile]()

                let scanHistoryEvents = brokersInfoData.flatMap { $0.scanOperationData.historyEvents }
                var status = ""

                if let date = self.getLastEventDate(events: scanHistoryEvents) {
                    status = "Last Scan \(date)"
                }

                self.headerStatusText = status

                for brokerProfileQueryData in brokersInfoData {
                    for optOutOperationData in brokerProfileQueryData.optOutOperationsData {
                        if optOutOperationData.extractedProfile.removedDate == nil {
                            var errorName: String?
                            var errorDescription: String?

                            let sortedEvents = optOutOperationData.historyEvents.sorted { $0.date < $1.date }
                            if let lastEvent = sortedEvents.last {
                                if case .error(let error) = lastEvent.type {
                                    errorName = error.userReadableError.title
                                    errorDescription = error.userReadableError.subtitle
                                }
                            }

                            let addresses = optOutOperationData.extractedProfile.addresses?.map { $0.fullAddress }.sorted() ?? ["No Address Found"]
                            let relatives = optOutOperationData.extractedProfile.relatives?.sorted() ?? ["No Relatives Found"]

                            let profile = PendingProfile(
                                dataBroker: brokerProfileQueryData.dataBroker.name,
                                profile: optOutOperationData.extractedProfile.fullName ?? "",
                                addresses: addresses,
                                age: optOutOperationData.extractedProfile.age,
                                relatives: relatives,
                                error: errorName,
                                errorDescription: errorDescription,
                                operationData: optOutOperationData)

                            pendingProfiles.append(profile)
                        } else {
                            let profile = RemovedProfile(dataBroker: brokerProfileQueryData.dataBroker.name,
                                                         scheduledDate: brokerProfileQueryData.scanOperationData.preferredRunDate)
                            removedProfiles.append(profile)
                        }
                    }
                }

                self.updateLoadingViewWithMinimumDuration(startTime: startTime, endTime: endTime) {
                    self.isLoading = false
                    self.removedProfiles = removedProfiles
                    self.pendingProfiles = pendingProfiles
                }
            }
        }
    }

    private func updateLoadingViewWithMinimumDuration(startTime: UInt64, endTime: UInt64, completion: @escaping () -> Void) {
        let durationInSeconds = Double(endTime - startTime) / 1_000_000_000

        // Calculate the delay time required to reach a minimum of 2 seconds
        let delayTime = max(2 - durationInSeconds, 0)

        DispatchQueue.main.asyncAfter(deadline: .now() + delayTime) {
            completion()
        }
    }

    private func getLastEventDate(events: [HistoryEvent]) -> String? {
        let sortedEvents = events.sorted(by: { $0.date < $1.date })
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        if let lastEvent = sortedEvents.last {
            return dateFormatter.string(from: lastEvent.date)
        } else {
            return nil
        }
    }

    @objc public func reloadData() {
        DispatchQueue.main.async {
            self.updateUI(ignoresCache: true)
        }
    }
}

extension DataBrokerProtectionError {
    var userReadableError: (title: String, subtitle: String) {
        let genericTitle = "Internal Error"

        switch self {
        case .malformedURL:
            return (title: genericTitle, subtitle: "Malformed URL")
        case .noActionFound:
            return (title: genericTitle, subtitle: "No action found")
        case .actionFailed(actionID: let actionID, message: let message):
            return (title: "Action \(actionID)", subtitle: message)
        case .parsingErrorObjectFailed:
            return (title: genericTitle, subtitle: "Parsing error")
        case .unknownMethodName:
            return (title: genericTitle, subtitle: "Unknown method name")
        case .userScriptMessageBrokerNotSet:
            return (title: genericTitle, subtitle: "User script")
        case .unknown:
            return (title: genericTitle, subtitle: "Unknown")
        case .unrecoverableError:
            return (title: genericTitle, subtitle: "Unrecoverable")
        case .noOptOutStep:
            return (title: genericTitle, subtitle: "Missing step")
        case .cancelled:
            return (title: genericTitle, subtitle: "Cancelled")
        case .solvingCaptchaWithCallbackError:
            return (title: genericTitle, subtitle: "Solving captcha with callback failed")
        case .captchaServiceError(let captchaError):
            let title = "Solver"
            switch captchaError {
            case .cantGenerateCaptchaServiceURL:
                return (title: title, subtitle: "Can't generate URL")
            case .nilTransactionIdWhenSubmittingCaptcha:
                return (title: title, subtitle: "Missing ID on submission")
            case .criticalFailureWhenSubmittingCaptcha:
                return (title: title, subtitle: "Critical failure")
            case .invalidRequestWhenSubmittingCaptcha:
                return (title: title, subtitle: "Submission invalid request")
            case .timedOutWhenSubmittingCaptcha:
                return (title: title, subtitle: "Submission timeout")
            case .errorWhenSubmittingCaptcha:
                return (title: title, subtitle: "Can't submit action")
            case .errorWhenFetchingCaptchaResult:
                return (title: title, subtitle: "Can't fetch result")
            case .nilDataWhenFetchingCaptchaResult:
                return (title: title, subtitle: "No data on result")
            case .timedOutWhenFetchingCaptchaResult:
                return (title: title, subtitle: "Fetching timeout")
            case .failureWhenFetchingCaptchaResult:
                return (title: title, subtitle: "Missing ID on fetch")
            case .invalidRequestWhenFetchingCaptchaResult:
                return (title: title, subtitle: "Fetch invalid request")
            case .cancelled:
                return (title: title, subtitle: "Cancelled")

            }
        case .emailError(let emailError):
            let title = "E-mail"
            guard let emailError = emailError else {
                return (title: title, subtitle: "Unknown error")
            }
            switch emailError {
            case .cantGenerateURL:
                return (title: title, subtitle: "Can't generate URL")
            case .cantFindEmail:
                return (title: title, subtitle: "Can't find E-mail")
            case .invalidEmailLink:
                return (title: title, subtitle: "Invalid Link")
            case .linkExtractionTimedOut:
                return (title: title, subtitle: "Timeout")
            case .cantDecodeEmailLink:
                return (title: title, subtitle: "Can't decode link")
            case .unknownStatusReceived:
                return (title: title, subtitle: "Unknown Status")
            case .cancelled:
                return (title: title, subtitle: "Cancelled")
            }
        }
    }
}
