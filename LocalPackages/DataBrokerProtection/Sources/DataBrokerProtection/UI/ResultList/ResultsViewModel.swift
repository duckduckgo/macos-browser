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
        let address: String
        let error: String?
        let errorDescription: String?
        let operationData: OptOutOperationData
        var hasError: Bool {
            error != nil
        }
    }

    @Published var removedProfiles =  [RemovedProfile]()
    @Published var pendingProfiles = [PendingProfile]()

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

    private func updateUI(ignoresCache: Bool) {
        let brokersInfoData = dataManager.fetchBrokerProfileQueryData(ignoresCache: ignoresCache)
        var removedProfiles = [RemovedProfile]()
        var pendingProfiles = [PendingProfile]()

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

                    let profile = PendingProfile(
                        dataBroker: brokerProfileQueryData.dataBroker.name,
                        profile: optOutOperationData.extractedProfile.fullName ?? "",
                        address: optOutOperationData.extractedProfile.addresses?.first?.fullAddress ?? "",
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

        self.removedProfiles = removedProfiles
        self.pendingProfiles = pendingProfiles
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
            return (title: genericTitle, subtitle: "Unkonwn method name")
        case .userScriptMessageBrokerNotSet:
            return (title: genericTitle, subtitle: "User script")
        case .unknown:
            return (title: genericTitle, subtitle: "Unkonwn")
        case .unrecoverableError:
            return (title: genericTitle, subtitle: "Unrecoverable")
        case .noOptOutStep:
            return (title: genericTitle, subtitle: "Missing step")
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
                return (title: title, subtitle: "Submission timout")
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
            }
        case .emailError(let emailError):
            var title = "E-mail"
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
            }
        }
    }
}
