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

                    if let lastEvent = optOutOperationData.historyEvents.last {
                        if case .error(let error) = lastEvent.type {
                            errorName = error.name
                            errorDescription = error.localizedDescription
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
