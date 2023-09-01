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
    private let notificationCenter: NotificationCenter
    private var statusCancellable: AnyCancellable?

    @Published var headerStatusText = ""
    @Published var schedulerStatus = ""

    internal init(scheduler: DataBrokerProtectionScheduler,
                  dataManager: DataBrokerProtectionDataManaging,
                  notificationCenter: NotificationCenter = .default) {
        self.scheduler = scheduler
        self.dataManager = dataManager
        self.notificationCenter = notificationCenter

        updateHeaderStatus()
        setupNotifications()
        setupCancellable()
        startSchedulerIfProfileAvailable()
    }

    private func setupCancellable() {
        statusCancellable = scheduler.statusPublisher
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
            }
    }

    private func startSchedulerIfProfileAvailable() {
        if dataManager.fetchProfile() != nil {
            startScheduler()
        }
    }

    private func setupNotifications() {
        notificationCenter.addObserver(self,
                                       selector: #selector(handleReloadNotification),
                                       name: DataBrokerProtectionNotifications.didFinishScan,
                                       object: nil)

        notificationCenter.addObserver(self,
                                       selector: #selector(handleReloadNotification),
                                       name: DataBrokerProtectionNotifications.didFinishOptOut,
                                       object: nil)
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

    @objc private func handleReloadNotification() {
        DispatchQueue.main.async {
            self.updateHeaderStatus()
        }
    }

    private func updateHeaderStatus() {
        let brokerProfileData = self.dataManager.fetchBrokerProfileQueryData()
        let scanHistoryEvents = brokerProfileData.flatMap { $0.scanOperationData.historyEvents }
        var status = ""

        if let date = getLastEventDate(events: scanHistoryEvents) {
            status = "Last Scan \(date)"
        }
        self.headerStatusText = status
    }

    func startScheduler() {
        if scheduler.status == .stopped {
            scheduler.start()
        }
    }

    func scan(completion: @escaping (ScanResult) -> Void) {
        scheduler.scanAllBrokers { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                let brokerProfileData = self.dataManager.fetchBrokerProfileQueryData()
                let data = brokerProfileData.filter { !$0.optOutOperationsData.isEmpty }

                if data.isEmpty {
                    completion(.noResults)
                } else {
                    completion(.results)
                }
            }
        }
    }
}
