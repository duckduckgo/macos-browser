//
//  DataBrokerForceOptOutViewModel.swift
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
import SecureStorage

final class DataBrokerForceOptOutViewModel: ObservableObject {
    private let dataManager: DataBrokerProtectionDataManager
    @Published var optOutData = [OptOutViewData]()

    internal init(dataManager: DataBrokerProtectionDataManager =
                  DataBrokerProtectionDataManager(pixelHandler: DataBrokerProtectionPixelsHandler())) {
        self.dataManager = dataManager
        loadNotRemovedOptOutData()
    }

    private func loadNotRemovedOptOutData() {
        Task { @MainActor in
            guard let brokerProfileData = try? await dataManager.fetchBrokerProfileQueryData(ignoresCache: true) else {
                assertionFailure()
                return
            }
            self.optOutData = brokerProfileData
                .flatMap { profileData in
                    profileData.optOutOperationsData.map { ($0, profileData.dataBroker.name) }
                }
                .filter { operationData, _ in
                    operationData.extractedProfile.removedDate == nil
                }
                .map { operationData, brokerName in
                    OptOutViewData(optOutOperationData: operationData, brokerName: brokerName)
                }.sorted(by: { $0.brokerName < $1.brokerName })
        }
    }

    func forceOptOut(_ data: OptOutViewData) {
        guard let extractedProfileID = data.extractedProfileID else { return }
        dataManager.setAsRemoved(extractedProfileID)
        loadNotRemovedOptOutData()
    }
}

struct OptOutViewData: Identifiable {
    let id: UUID
    let optOutOperationData: OptOutOperationData
    let profileName: String
    let brokerName: String
    let extractedProfileID: Int64?

    internal init(optOutOperationData: OptOutOperationData, brokerName: String) {
        self.optOutOperationData = optOutOperationData
        self.extractedProfileID = optOutOperationData.extractedProfile.id
        self.brokerName = brokerName
        self.profileName = "\(extractedProfileID ?? 0) \(optOutOperationData.extractedProfile.fullName ?? "No Name")"
        self.id = UUID()
    }
}

private extension DataBrokerProtectionDataManager {

    func setAsRemoved(_ extractedProfileID: Int64) {
        do {
            try self.database.updateRemovedDate(Date(), on: extractedProfileID)
        } catch {
            assertionFailure()
        }
    }
}
