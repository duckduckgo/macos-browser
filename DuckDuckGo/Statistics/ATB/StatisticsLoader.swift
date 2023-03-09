//
//  StatisticsLoader.swift
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
import BrowserServicesKit
import os.log
import Networking

final class StatisticsLoader {

    typealias Completion =  (() -> Void)

    static let shared = StatisticsLoader()

    private let statisticsStore: StatisticsStore
    private let emailManager: EmailManager
    private let parser = AtbParser()
    private var isAppRetentionRequestInProgress = false

    init(statisticsStore: StatisticsStore = LocalStatisticsStore(), emailManager: EmailManager = EmailManager()) {
        self.statisticsStore = statisticsStore
        self.emailManager = emailManager
    }

    func refreshRetentionAtb(isSearch: Bool, completion: @escaping Completion = {}) {
        // Search ATB is the only call being used currently. This guard statement can be removed to re-enable app retention ATB.
        guard isSearch else {
            completion()
            return
        }

        load {
            dispatchPrecondition(condition: .onQueue(.main))

            if isSearch {
                self.refreshSearchRetentionAtb {
                    self.refreshRetentionAtb(isSearch: false) {
                        completion()
                    }
                }
                Pixel.fire(.serp)
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

        guard !isAppRetentionRequestInProgress else { return }
        isAppRetentionRequestInProgress = true

        os_log("Requesting install statistics", log: .atb, type: .debug)

        let configuration = APIRequest.Configuration(url: URL.initialAtb)
        let request = APIRequest(configuration: configuration, urlSession: URLSession.session(useMainThreadCallbackQueue: true))
        request.fetch { response, error in
            self.isAppRetentionRequestInProgress = false
            if let error = error {
                os_log("Initial atb request failed with error %s", type: .error, error.localizedDescription)
                completion()
                return
            }

            os_log("Install statistics request succeeded", log: .atb, type: .debug)

            if let data = response?.data, let atb = try? self.parser.convert(fromJsonData: data) {
                self.requestExti(atb: atb, completion: completion)
            } else {
                completion()
            }
        }
    }

    private func requestExti(atb: Atb, completion: @escaping Completion = {}) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard !isAppRetentionRequestInProgress else { return }
        self.isAppRetentionRequestInProgress = true

        os_log("Requesting exti", log: .atb, type: .debug)

        let installAtb = atb.version + (statisticsStore.variant ?? "")

        let configuration = APIRequest.Configuration(url: URL.exti(forAtb: installAtb))
        let request = APIRequest(configuration: configuration, urlSession: URLSession.session(useMainThreadCallbackQueue: true))
        request.fetch { _, error in
            self.isAppRetentionRequestInProgress = false
            if let error = error {
                os_log("Exti request failed with error %s", type: .error, error.localizedDescription)
                completion()
                return
            }

            os_log("Exti request succeeded", log: .atb, type: .debug)

            assert(self.statisticsStore.atb == nil)
            assert(self.statisticsStore.installDate == nil)

            self.statisticsStore.installDate = Date()
            self.statisticsStore.atb = atb.version
            completion()
        }
    }

    func refreshSearchRetentionAtb(completion: @escaping Completion = {}) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let atbWithVariant = statisticsStore.atbWithVariant,
              let searchRetentionAtb = statisticsStore.searchRetentionAtb ?? statisticsStore.atb
        else {
            requestInstallStatistics(completion: completion)
            return
        }

        os_log("Requesting search retention ATB", log: .atb, type: .debug)

        let url = URL.searchAtb(atbWithVariant: atbWithVariant, setAtb: searchRetentionAtb, isSignedIntoEmailProtection: emailManager.isSignedIn)
        let configuration = APIRequest.Configuration(url: url)
        let request = APIRequest(configuration: configuration, urlSession: URLSession.session(useMainThreadCallbackQueue: true))
        request.fetch { (response, error) in
            if let error = error {
                os_log("Search atb request failed with error %s", type: .error, error.localizedDescription)
                completion()
                return
            }

            os_log("Search retention ATB request succeeded", log: .atb, type: .debug)

            if let data = response?.data, let atb  = try? self.parser.convert(fromJsonData: data) {
                self.statisticsStore.searchRetentionAtb = atb.version
                self.storeUpdateVersionIfPresent(atb)
            }

            completion()
        }
    }

    func refreshAppRetentionAtb(completion: @escaping Completion = {}) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard !isAppRetentionRequestInProgress,
              let atbWithVariant = statisticsStore.atbWithVariant,
              let appRetentionAtb = statisticsStore.appRetentionAtb ?? statisticsStore.atb
        else {
            requestInstallStatistics(completion: completion)
            return
        }

        os_log("Requesting app retention ATB", log: .atb, type: .debug)

        isAppRetentionRequestInProgress = true

        let url = URL.appRetentionAtb(atbWithVariant: atbWithVariant, setAtb: appRetentionAtb)
        let configuration = APIRequest.Configuration(url: url)
        let request = APIRequest(configuration: configuration, urlSession: URLSession.session(useMainThreadCallbackQueue: true))
        request.fetch { response, error in
            self.isAppRetentionRequestInProgress = false

            if let error = error {
                os_log("App atb request failed with error %s", type: .error, error.localizedDescription)
                completion()
                return
            }

            os_log("App retention ATB request succeeded", log: .atb, type: .debug)

            if let data = response?.data, let atb  = try? self.parser.convert(fromJsonData: data) {
                self.statisticsStore.appRetentionAtb = atb.version
                self.statisticsStore.lastAppRetentionRequestDate = Date()
                self.storeUpdateVersionIfPresent(atb)
            }

            completion()
        }
    }

    func storeUpdateVersionIfPresent(_ atb: Atb) {
        dispatchPrecondition(condition: .onQueue(.main))

        if let updateVersion = atb.updateVersion {
            statisticsStore.atb = updateVersion
        }
    }

}
