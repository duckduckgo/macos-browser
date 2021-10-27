//
//  StatisticsLoader.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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
import os.log

final class StatisticsLoader {
    
    typealias Completion =  (() -> Void)
    
    static let shared = StatisticsLoader()
    
    private let statisticsStore: StatisticsStore
    private let parser = AtbParser()
    private var isAppRetentionRequestInProgress = false
    
    init(statisticsStore: StatisticsStore = StatisticsUserDefaults()) {
        self.statisticsStore = statisticsStore
    }

    func refreshRetentionAtb(isSearch: Bool, completion: @escaping Completion = {}) {
        load {
            dispatchPrecondition(condition: .onQueue(.main))

            if isSearch {
                self.refreshSearchRetentionAtb(completion: completion)
            } else if !self.statisticsStore.isAppRetentionFiredToday {
                self.refreshAppRetentionAtb(completion: completion)
            } else {
                completion()
            }
        }
    }

    func load(completion: @escaping Completion = {}) {
        if statisticsStore.hasInstallStatistics {
            completion()
            return
        }
        requestInstallStatistics(completion: completion)
    }
    
    private func requestInstallStatistics(completion: @escaping Completion = {}) {
        dispatchPrecondition(condition: .onQueue(.main))

        APIRequest.request(url: URL.initialAtb) { response, error in
            DispatchQueue.main.async {
                if let error = error {
                    os_log("Initial atb request failed with error %s", type: .error, error.localizedDescription)
                    completion()
                    return
                }

                if let data = response?.data, let atb  = try? self.parser.convert(fromJsonData: data) {
                    self.requestExti(atb: atb, completion: completion)
                } else {
                    completion()
                }
            }
        }
    }
    
    private func requestExti(atb: Atb, completion: @escaping Completion = {}) {
        dispatchPrecondition(condition: .onQueue(.main))

        let installAtb = atb.version + (statisticsStore.variant ?? "")
        guard let url = URL.exti(forAtb: installAtb) else { return }

        APIRequest.request(url: url) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    os_log("Exti request failed with error %s", type: .error, error.localizedDescription)
                    completion()
                    return
                }
                self.statisticsStore.installDate = Date()
                self.statisticsStore.atb = atb.version
                completion()
            }
        }
    }
    
    func refreshSearchRetentionAtb(completion: @escaping Completion = {}) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let atbWithVariant = statisticsStore.atbWithVariant,
              let searchRetentionAtb = statisticsStore.searchRetentionAtb ?? statisticsStore.atb,
              let url = URL.searchAtb(atbWithVariant: atbWithVariant, setAtb: searchRetentionAtb)
        else {
            requestInstallStatistics(completion: completion)
            return
        }

        APIRequest.request(url: url) { response, error in
            DispatchQueue.main.async {
                if let error = error {
                    os_log("Search atb request failed with error %s", type: .error, error.localizedDescription)
                    completion()
                    return
                }
                if let data = response?.data, let atb  = try? self.parser.convert(fromJsonData: data) {
                    self.statisticsStore.searchRetentionAtb = atb.version
                    self.storeUpdateVersionIfPresent(atb)
                }
                completion()
            }
        }
    }
    
    func refreshAppRetentionAtb(completion: @escaping Completion = {}) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard !isAppRetentionRequestInProgress,
              let atbWithVariant = statisticsStore.atbWithVariant,
              let appRetentionAtb = statisticsStore.appRetentionAtb ?? statisticsStore.atb,
              let url = URL.appRetentionAtb(atbWithVariant: atbWithVariant, setAtb: appRetentionAtb)
        else {
            requestInstallStatistics(completion: completion)
            return
        }

        isAppRetentionRequestInProgress = true
        APIRequest.request(url: url) { response, error in
            DispatchQueue.main.async {
                self.isAppRetentionRequestInProgress = false

                if let error = error {
                    os_log("App atb request failed with error %s", type: .error, error.localizedDescription)
                    completion()
                    return
                }
                if let data = response?.data, let atb  = try? self.parser.convert(fromJsonData: data) {
                    self.statisticsStore.appRetentionAtb = atb.version
                    self.statisticsStore.lastAppRetentionRequestDate = Date()
                    self.storeUpdateVersionIfPresent(atb)
                }
                completion()
            }
        }
    }

    func storeUpdateVersionIfPresent(_ atb: Atb) {
        dispatchPrecondition(condition: .onQueue(.main))
        
        if let updateVersion = atb.updateVersion {
            statisticsStore.atb = updateVersion
        }
    }

}
