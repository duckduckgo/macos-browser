//
//  ContainerViewModel.swift
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
import Combine

final class ContainerViewModel: ObservableObject {
    enum ScanResult {
        case noResults
        case results
    }

    private let scheduler: DataBrokerProtectionScheduler
    private let dataManager: DataBrokerProtectionDataManaging

    @Published var scanResults: ScanResult?
    @Published var showWebView = false
    @Published var useFakeBroker = false
    @Published var preventSchedulerStart = false

    internal init(scheduler: DataBrokerProtectionScheduler,
                  dataManager: DataBrokerProtectionDataManaging) {
        self.scheduler = scheduler
        self.dataManager = dataManager

        restoreFakeBrokerStatus()
    }

    private func restoreFakeBrokerStatus() {
        useFakeBroker = DataBrokerDebugFlagFakeBroker().isFlagOn()
        preventSchedulerStart = DataBrokerDebugFlagBlockScheduler().isFlagOn()
        showWebView = DataBrokerDebugFlagShowWebView().isFlagOn()
    }

    func runQueuedOperationsAndStartScheduler() {
        scheduler.runQueuedOperations(showWebView: showWebView) { [scheduler] error in
            guard error == nil else {
                return
            }

            scheduler.startScheduler(showWebView: self.showWebView)
        }
    }

    func forceSchedulerRun() {
        scheduler.runAllOperations(showWebView: showWebView)
    }

    func forceRunScans(completion: @escaping (ScanResult) -> Void) {
        scanAndUpdateUI(completion: completion)
    }

    func forceRunOptOuts() {
        scheduler.optOutAllBrokers(showWebView: showWebView, completion: nil)
    }

    func cleanData() {
        let fileManager = FileManager.default
        // Not the best way to hardcode this, but it's just for the debug UI
        let filePath = NSHomeDirectory() + "/Library/Containers/com.duckduckgo.macos.browser.dbp.debug/Data/Library/Application Support/DBP/Vault.db"

        do {
            try fileManager.removeItem(atPath: filePath)
        } catch {
            print("Error removing file: \(error.localizedDescription)")
        }
        exit(0)
    }

    func scanAfterProfileCreation(completion: @escaping (ScanResult) -> Void) {
        scanAndUpdateUI(completion: completion)
    }

    private func scanAndUpdateUI(completion: @escaping (ScanResult) -> Void) {
        scheduler.scanAllBrokers(showWebView: self.showWebView) { [weak self] error in
            guard error == nil, let self = self else { return }

            DispatchQueue.main.async {
                let hasResults = self.dataManager.hasMatches()

                if hasResults {
                    completion(.results)
                } else {
                    completion(.noResults)
                }
            }
        }
    }
}
