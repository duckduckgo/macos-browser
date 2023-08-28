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

        var hasError: Bool {
            error != nil
        }
    }

    @Published var removedProfiles =  [RemovedProfile]()
    @Published var pendingProfiles = [PendingProfile]()

    init(dataManager: DataBrokerProtectionDataManaging) {
        self.dataManager = dataManager
        updateUI()
    }

    private func updateUI() {
        let brokersInfoData = dataManager.fetchBrokerProfileQueryData()
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
                        errorDescription: errorDescription)

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

    public func reloadData() {
        updateUI()
    }
    
    // MARK: - Test Data
    private func addFakeData() {
        removedProfiles = [
            RemovedProfile(dataBroker: "ABC Data Broker", scheduledDate: Date()),
            RemovedProfile(dataBroker: "XYZ Data Broker", scheduledDate: Date().addingTimeInterval(86400)),
            RemovedProfile(dataBroker: "DEF Data Broker", scheduledDate: Date().addingTimeInterval(86400 * 2)),
            RemovedProfile(dataBroker: "GHI Data Broker", scheduledDate: Date().addingTimeInterval(86400 * 3)),
            RemovedProfile(dataBroker: "JKL Data Broker", scheduledDate: Date().addingTimeInterval(86400 * 4))
        ]

        pendingProfiles = [
            PendingProfile(dataBroker: "ABC Data Broker", profile: "John Doe", address: "123 Apple Street", error: nil, errorDescription: nil),
            PendingProfile(dataBroker: "XYZ Data Broker", profile: "Jane Smith", address: "456 Cherry Avenue", error: "Error", errorDescription: "Error Description"),
            PendingProfile(dataBroker: "DEF Data Broker", profile: "Michael Johnson", address: "789 Orange Road", error: nil, errorDescription: nil),
            PendingProfile(dataBroker: "GHI Data Broker", profile: "Emily Davis", address: "321 Banana Boulevard", error: "Error", errorDescription: "Error Description"),
            PendingProfile(dataBroker: "JKL Data Broker", profile: "Matthew Wilson", address: "654 Grape Lane", error: nil, errorDescription: nil),
            PendingProfile(dataBroker: "MNO Data Broker", profile: "Olivia Taylor", address: "987 Lemon Drive", error: "Error", errorDescription: "Error Description")
        ]

        startMovingProfiles()
    }

    private var timer: Timer?
    private var secondsElapsed: Int = 0

    func startMovingProfiles() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            self?.moveProfileToRemoved()
            self?.secondsElapsed += 1

            if self?.secondsElapsed == 10 {
                timer.invalidate()
            }
        }
    }

    private func moveProfileToRemoved() {
        if let profile = pendingProfiles.first {
            withAnimation {
                pendingProfiles.removeFirst()
                removedProfiles.append(RemovedProfile(dataBroker: profile.dataBroker, scheduledDate: Date()))
            }
        }
    }
}
