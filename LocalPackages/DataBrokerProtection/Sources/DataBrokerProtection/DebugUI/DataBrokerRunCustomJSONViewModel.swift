//
//  DataBrokerRunCustomJSONViewModel.swift
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
import BrowserServicesKit
import Common
import ContentScopeScripts
import Combine

struct AlertUI {
    var title: String = ""
    var description: String = ""

    static func noResults() -> AlertUI {
        AlertUI(title: "No results", description: "No results were found.")
    }

    static func from(error: DataBrokerProtectionError) -> AlertUI {
        AlertUI(title: error.title, description: error.description)
    }
}

final class DataBrokerRunCustomJSONViewModel: ObservableObject {

    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var middle: String = ""
    @Published var city: String = ""
    @Published var state: String = ""
    @Published var birthYear: String = ""
    @Published var results = [ExtractedProfile]()
    @Published var showAlert = false
    @Published var showNoResults = false
    var alert: AlertUI?
    var selectedDataBroker: DataBroker?

    let brokers: [DataBroker]

    private let runnerProvider: OperationRunnerProvider

    init() {
        let privacyConfigurationManager = PrivacyConfigurationManagingMock()
        let features = ContentScopeFeatureToggles(emailProtection: false,
                                                  emailProtectionIncontextSignup: false,
                                                  credentialsAutofill: false,
                                                  identitiesAutofill: false,
                                                  creditCardsAutofill: false,
                                                  credentialsSaving: false,
                                                  passwordGeneration: false,
                                                  inlineIconCredentials: false,
                                                  thirdPartyCredentialsProvider: false)

        let sessionKey = UUID().uuidString
        let contentScopeProperties = ContentScopeProperties(gpcEnabled: false,
                                                            sessionKey: sessionKey,
                                                            featureToggles: features)
        self.runnerProvider = DataBrokerOperationRunnerProvider(
            privacyConfigManager: privacyConfigurationManager,
            contentScopeProperties: contentScopeProperties,
            emailService: EmailService(),
            captchaService: CaptchaService())

        let fileResources = FileResources()
        self.brokers = fileResources.fetchBrokerFromResourceFiles() ?? [DataBroker]()
    }

    func runJSON(jsonString: String) {
        if firstName.isEmpty || lastName.isEmpty || city.isEmpty || state.isEmpty || birthYear.isEmpty {
            self.showAlert = true
            self.alert = AlertUI(title: "Error", description: "Some required fields were not entered.")
            return
        }

        if let data = jsonString.data(using: .utf8) {
            do {
                let decoder = JSONDecoder()
                let dataBroker = try decoder.decode(DataBroker.self, from: data)
                self.selectedDataBroker = dataBroker
                let brokerProfileQueryData = createBrokerProfileQueryData(for: dataBroker)

                let runner = runnerProvider.getOperationRunner()

                Task {
                    do {
                        let extractedProfiles = try await runner.scan(brokerProfileQueryData, stageCalculator: FakeStageDurationCalculator(), showWebView: true) { true }

                        DispatchQueue.main.async {
                            if extractedProfiles.isEmpty {
                                self.showNoResultsAlert()
                            } else {
                                self.results = extractedProfiles
                            }
                        }
                    } catch {
                        showAlert(for: error)
                    }
                }
            } catch {
                showAlert(for: error)
            }
        }
    }

    func runOptOut(extractedProfile: ExtractedProfile) {
        let runner = runnerProvider.getOperationRunner()
        guard let dataBroker = self.selectedDataBroker else {
            print("No broker selected")
            return
        }

        let brokerProfileQueryData = createBrokerProfileQueryData(for: dataBroker)

        Task {
            do {
                try await runner.optOut(profileQuery: brokerProfileQueryData, extractedProfile: extractedProfile, stageCalculator: FakeStageDurationCalculator(), showWebView: true) {
                    true
                }

                DispatchQueue.main.async {
                    self.showAlert = true
                    self.alert = AlertUI(title: "Success!", description: "We finished the opt out process for the selected profile.")
                }

            } catch {
                showAlert(for: error)
            }
        }
    }

    private func createBrokerProfileQueryData(for dataBroker: DataBroker) -> BrokerProfileQueryData {
        let profile = createProfile()
        let fakeScanOperationData = ScanOperationData(brokerId: 0, profileQueryId: 0, historyEvents: [HistoryEvent]())
        return BrokerProfileQueryData(dataBroker: dataBroker, profileQuery: profile.profileQueries.first!, scanOperationData: fakeScanOperationData)
    }

    private func showNoResultsAlert() {
        DispatchQueue.main.async {
            self.showAlert = true
            self.alert = AlertUI.noResults()
        }
    }

    private func showAlert(for error: Error) {
        DispatchQueue.main.async {
            self.showAlert = true
            if let dbpError = error as? DataBrokerProtectionError {
                self.alert = AlertUI.from(error: dbpError)
            }

            print("Error when scanning: \(error)")
        }
    }

    private func createProfile() -> DataBrokerProtectionProfile {
        let names = DataBrokerProtectionProfile.Name(firstName: firstName, lastName: lastName, middleName: middle)
        let addresses = DataBrokerProtectionProfile.Address(city: city, state: state)

        return DataBrokerProtectionProfile(names: [names], addresses: [addresses], phones: [String](), birthYear: Int(birthYear) ?? 1990)
    }

    func appVersion() -> String {
        AppVersion.shared.versionNumber
    }

    func contentScopeScriptsVersion() -> String {
        // How can I return this?
        return "4.59.2"
    }
}

final class FakeStageDurationCalculator: StageDurationCalculator {
    func durationSinceLastStage() -> Double {
        0.0
    }

    func durationSinceStartTime() -> Double {
        0.0
    }

    func fireOptOutStart() {
    }

    func fireOptOutEmailGenerate() {
    }

    func fireOptOutCaptchaParse() {
    }

    func fireOptOutCaptchaSend() {
    }

    func fireOptOutCaptchaSolve() {
    }

    func fireOptOutSubmit() {
    }

    func fireOptOutEmailReceive() {
    }

    func fireOptOutEmailConfirm() {
    }

    func fireOptOutValidate() {
    }

    func fireOptOutSubmitSuccess() {
    }

    func fireOptOutFailure() {
    }

    func fireScanSuccess(matchesFound: Int) {
    }

    func fireScanFailed() {
    }

    func fireScanError(error: Error) {
    }

    func setStage(_ stage: Stage) {
    }
}

/*
 I wasn't able to import this mock from the background agent project, so I had to re-use it here.
 */
private final class PrivacyConfigurationManagingMock: PrivacyConfigurationManaging {

    var data: Data {
        let configString = """
    {
            "readme": "https://github.com/duckduckgo/privacy-configuration",
            "version": 1693838894358,
            "features": {
                "brokerProtection": {
                    "state": "enabled",
                    "exceptions": [],
                    "settings": {}
                }
            },
            "unprotectedTemporary": []
        }
    """
        let data = configString.data(using: .utf8)
        return data!
    }

    var currentConfig: Data {
        data
    }

    var updatesPublisher: AnyPublisher<Void, Never> = .init(Just(()))

    var privacyConfig: BrowserServicesKit.PrivacyConfiguration {
        guard let privacyConfigurationData = try? PrivacyConfigurationData(data: data) else {
            fatalError("Could not retrieve privacy configuration data")
        }
        let privacyConfig = privacyConfiguration(withData: privacyConfigurationData,
                                                 internalUserDecider: internalUserDecider,
                                                 toggleProtectionsCounter: toggleProtectionsCounter)
        return privacyConfig
    }

    var internalUserDecider: InternalUserDecider = DefaultInternalUserDecider(store: InternalUserDeciderStoreMock())

    var toggleProtectionsCounter: ToggleProtectionsCounter = ToggleProtectionsCounter(eventReporting: EventMapping<ToggleProtectionsCounterEvent> { _, _, _, _ in
    })

    func reload(etag: String?, data: Data?) -> PrivacyConfigurationManager.ReloadResult {
        .downloaded
    }
}

func privacyConfiguration(withData data: PrivacyConfigurationData,
                          internalUserDecider: InternalUserDecider,
                          toggleProtectionsCounter: ToggleProtectionsCounter) -> PrivacyConfiguration {
    let domain = MockDomainsProtectionStore()
    return AppPrivacyConfiguration(data: data,
                                   identifier: UUID().uuidString,
                                   localProtection: domain,
                                   internalUserDecider: internalUserDecider,
                                   toggleProtectionsCounter: toggleProtectionsCounter)
}

final class MockDomainsProtectionStore: DomainsProtectionStore {
    var unprotectedDomains = Set<String>()

    func disableProtection(forDomain domain: String) {
        unprotectedDomains.insert(domain)
    }

    func enableProtection(forDomain domain: String) {
        unprotectedDomains.remove(domain)
    }
}

final class InternalUserDeciderStoreMock: InternalUserStoring {
    var isInternalUser: Bool = false
}

extension DataBroker {
    func toJSONString() -> String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // Optional: for pretty-printed JSON
            let jsonData = try encoder.encode(self)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }

            return ""
        } catch {
            print("Error encoding object to JSON: \(error)")
            return ""
        }

    }
}

extension DataBrokerProtectionError {
    var title: String {
        switch self {
        case .httpError(let code):
            if code == 404 {
                return "No results."
            } else {
                return "Error."
            }
        default: return "Error"
        }
    }

    var description: String {
        switch self {
        case .httpError(let code):
            if code == 404 {
                return "No results were found."
            } else {
                return "Failed with HTTP error code: \(code)"
            }
        default: return name
        }
    }
}
