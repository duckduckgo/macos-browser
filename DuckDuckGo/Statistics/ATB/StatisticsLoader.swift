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
    
    init(statisticsStore: StatisticsStore = StatisticsUserDefaults()) {
        self.statisticsStore = statisticsStore
    }

    func load(completion: @escaping Completion = {}) {
        if statisticsStore.hasInstallStatistics {
            completion()
            return
        }
        requestInstallStatistics(completion: completion)
    }
    
    private func requestInstallStatistics(completion: @escaping Completion = {}) {
        APIRequest.request(url: URL.initialAtb) { response, error in
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
    
    private func requestExti(atb: Atb, completion: @escaping Completion = {}) {
        let installAtb = atb.version + (statisticsStore.variant ?? "")
        guard let url = URL.exti(forAtb: installAtb) else { return }

        APIRequest.request(url: url) { _, error in
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
    
    func refreshSearchRetentionAtb(completion: @escaping Completion = {}) {
        guard let atbWithVariant = statisticsStore.atbWithVariant,
              let searchRetentionAtb = statisticsStore.searchRetentionAtb,
              let url = URL.searchAtb(atbWithVariant: atbWithVariant, setAtb: searchRetentionAtb)
        else {
            requestInstallStatistics(completion: completion)
            return
        }

        APIRequest.request(url: url) { response, error in
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
    
    func refreshAppRetentionAtb(completion: @escaping Completion = {}) {
        guard let atbWithVariant = statisticsStore.atbWithVariant,
              let appRetentionAtb = statisticsStore.appRetentionAtb,
              let url = URL.appRetentionAtb(atbWithVariant: atbWithVariant, setAtb: appRetentionAtb)
        else {
            requestInstallStatistics(completion: completion)
            return
        }

        APIRequest.request(url: url) { response, error in
            if let error = error {
                os_log("App atb request failed with error %s", type: .error, error.localizedDescription)
                completion()
                return
            }
            if let data = response?.data, let atb  = try? self.parser.convert(fromJsonData: data) {
                self.statisticsStore.appRetentionAtb = atb.version
                self.storeUpdateVersionIfPresent(atb)
            }
            completion()
        }
    }

    func storeUpdateVersionIfPresent(_ atb: Atb) {
        if let updateVersion = atb.updateVersion {
            statisticsStore.atb = updateVersion
        }
    }
}
