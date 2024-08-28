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

import Common
import Foundation
import BrowserServicesKit
import Networking
import PixelKit
import os.log

final class StatisticsLoader {

    typealias Completion =  (() -> Void)

    static let shared = StatisticsLoader()

    private let statisticsStore: StatisticsStore
    private let emailManager: EmailManager
    private let attributionPixelHandler: InstallationAttributionsPixelHandler
    private let parser = AtbParser()
    private var isAppRetentionRequestInProgress = false

    init(
        statisticsStore: StatisticsStore = LocalStatisticsStore(),
        emailManager: EmailManager = EmailManager(),
        attributionPixelHandler: InstallationAttributionsPixelHandler = AppInstallationAttributionPixelHandler()
    ) {
        self.statisticsStore = statisticsStore
        self.emailManager = emailManager
        self.attributionPixelHandler = attributionPixelHandler
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
                PixelExperiment.fireSerpPixel()
                PixelExperiment.fireOnboardingSearchPerformed5to7Pixel()
                self.fireDailyOsVersionCounterPixel()
                self.fireDockPixel()
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

        Logger.atb.debug("Requesting install statistics")

        let configuration = APIRequest.Configuration(url: URL.initialAtb)
        let request = APIRequest(configuration: configuration, urlSession: URLSession.session(useMainThreadCallbackQueue: true))
        request.fetch { response, error in
            self.isAppRetentionRequestInProgress = false
            if let error = error {
                Logger.atb.error("Initial atb request failed with error \(error.localizedDescription)")
                completion()
                return
            }

            Logger.atb.debug("Install statistics request succeeded")

            if let data = response?.data, let atb = try? self.parser.convert(fromJsonData: data) {
                self.requestExti(atb: atb, completion: completion)
                self.attributionPixelHandler.fireInstallationAttributionPixel()
            } else {
                completion()
            }
        }
    }

    private func requestExti(atb: Atb, completion: @escaping Completion = {}) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard !isAppRetentionRequestInProgress else { return }
        self.isAppRetentionRequestInProgress = true

        Logger.atb.debug("Requesting exti")

        let installAtb = atb.version + (statisticsStore.variant ?? "")

        let configuration = APIRequest.Configuration(url: URL.exti(forAtb: installAtb))
        let request = APIRequest(configuration: configuration, urlSession: URLSession.session(useMainThreadCallbackQueue: true))
        request.fetch { _, error in
            self.isAppRetentionRequestInProgress = false
            if let error = error {
                Logger.atb.error("Extit request failed with error \(error.localizedDescription)")
                completion()
                return
            }

            Logger.atb.debug("Exti request succeeded")

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

        Logger.atb.debug("Requesting search retention ATB")

        let url = URL.searchAtb(atbWithVariant: atbWithVariant, setAtb: searchRetentionAtb, isSignedIntoEmailProtection: emailManager.isSignedIn)
        let configuration = APIRequest.Configuration(url: url)
        let request = APIRequest(configuration: configuration, urlSession: URLSession.session(useMainThreadCallbackQueue: true))
        request.fetch { (response, error) in
            if let error = error {
                Logger.atb.error("Search atb request failed with error \(error.localizedDescription)")
                completion()
                return
            }

            Logger.atb.debug("Search retention ATB request succeeded")

            if let data = response?.data, let atb  = try? self.parser.convert(fromJsonData: data) {
                self.statisticsStore.searchRetentionAtb = atb.version
                self.storeUpdateVersionIfPresent(atb)
                NotificationCenter.default.post(name: .searchDAU, object: nil, userInfo: nil)
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

        Logger.atb.debug("Requesting app retention ATB")

        isAppRetentionRequestInProgress = true

        let url = URL.appRetentionAtb(atbWithVariant: atbWithVariant, setAtb: appRetentionAtb)
        let configuration = APIRequest.Configuration(url: url)
        let request = APIRequest(configuration: configuration, urlSession: URLSession.session(useMainThreadCallbackQueue: true))
        request.fetch { response, error in
            self.isAppRetentionRequestInProgress = false

            if let error = error {
                Logger.atb.error("App atb request failed with error \(error.localizedDescription)")
                completion()
                return
            }

            Logger.atb.debug("App retention ATB request succeeded")

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
            statisticsStore.variant = nil
        }
    }

    private func fireDailyOsVersionCounterPixel() {
        // To avoid temporal correlation attacks, add a randomized delay of 0.5-5 seconds
        let randomDelay = Double.random(in: 0.5...5)

        DispatchQueue.global().asyncAfter(deadline: .now() + randomDelay) {
            PixelKit.fire(GeneralPixel.dailyOsVersionCounter,
                          frequency: .legacyDaily,
                          includeAppVersionParameter: false)
        }
    }

    private func fireDockPixel() {
        DispatchQueue.global().asyncAfter(deadline: .now() + Double.random(in: 0.5...5)) {
            if DockCustomizer().isAddedToDock {
                PixelKit.fire(GeneralPixel.serpAddedToDock,
                              includeAppVersionParameter: false)
            }
        }
    }

}
