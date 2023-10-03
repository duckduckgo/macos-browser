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

    private let mainAppInterface: DBPPackageToMainAppInterface
    private let dataManager: DataBrokerProtectionDataManaging
    private var cancellables = Set<AnyCancellable>()

    @Published var schedulerStatus = ""
    @Published var showWebView = false
    @Published var useFakeBroker = false
    @Published var preventSchedulerStart = false

    internal init(mainAppInterface: DBPPackageToMainAppInterface,
                  dataManager: DataBrokerProtectionDataManaging) {
        self.mainAppInterface = mainAppInterface
        self.dataManager = dataManager

        restoreFakeBrokerStatus()
        setupCancellable()
    }

    private func setupCancellable() {
        /*scheduler.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in

                switch status {
                case .idle:
                    self?.schedulerStatus = "🟠 Idle"
                case .running:
                    self?.schedulerStatus = "🟢 Running"
                case .stopped:
                    self?.schedulerStatus = "🔴 Stopped"
                }
            }.store(in: &cancellables)

        $useFakeBroker
            .receive(on: DispatchQueue.main)
            .sink { value in
                DataBrokerDebugFlagFakeBroker().setFlag(value)
            }.store(in: &cancellables)

        $preventSchedulerStart
            .receive(on: DispatchQueue.main)
            .sink { value in
                DataBrokerDebugFlagBlockScheduler().setFlag(value)
            }.store(in: &cancellables)

        $showWebView
            .receive(on: DispatchQueue.main)
            .sink { value in
                DataBrokerDebugFlagShowWebView().setFlag(value)
            }.store(in: &cancellables)
         */
    }

    private func restoreFakeBrokerStatus() {
        useFakeBroker = DataBrokerDebugFlagFakeBroker().isFlagOn()
        preventSchedulerStart = DataBrokerDebugFlagBlockScheduler().isFlagOn()
        showWebView = DataBrokerDebugFlagShowWebView().isFlagOn()
    }

//    func runQueuedOperationsAndStartScheduler() {
//        scheduler.runQueuedOperations(showWebView: showWebView) { [weak self] in
//            guard let self = self else { return }
//            self.scheduler.startScheduler(showWebView: self.showWebView)
//        }
//    }

    func forceSchedulerRun() {
        mainAppInterface.runAllOperations(showWebView: showWebView)
    }

    func startScanPressed() {
        mainAppInterface.startScanPressed()
    }

    func forceRunScans(completion: @escaping (ScanResult) -> Void) {
        scanAndUpdateUI(completion: completion)
    }

    func forceRunOptOuts() {
        scheduler.optOutAllBrokers(showWebView: showWebView, completion: {})
    }

    func stopAllOperations() {
        scheduler.stopScheduler()
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
        scheduler.stopScheduler()

        scheduler.scanAllBrokers(showWebView: showWebView) { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                let hasResults = self.dataManager.hasMatches()

                if hasResults {
                    completion(.results)
                } else {
                    completion(.noResults)
                }
            }
        }*/
    }

    func editProfilePressed() {
        mainAppInterface.profileModified()
    }
}

extension ContainerViewModel: MainAppToDBPPackageInterface {

    func brokersScanCompleted() {
        DispatchQueue.main.async {
            let hasResults = self.dataManager.hasMatches()

            if hasResults {
                //TODO view needs a thing for this.
                //in general have no idea  how we're gonna deal with its state
                //completion(.results)
            } else {
                //completion(.noResults)
            }
        }
    }
}
