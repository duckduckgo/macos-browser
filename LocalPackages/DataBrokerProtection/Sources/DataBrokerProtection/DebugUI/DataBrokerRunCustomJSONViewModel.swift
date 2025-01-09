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
import os.log

struct ExtractedAddress: Codable {
    let state: String
    let city: String
}

struct UserData: Codable {
    let firstName: String
    let lastName: String
    let middleName: String?
    let state: String
    let email: String?
    let city: String
    let age: Int
    let addresses: [ExtractedAddress]
}

struct ProfileUrl: Codable {
    let profileUrl: String
    let identifier: String
}

struct ScrapedData: Codable {
    let name: String?
    let alternativeNamesList: [String]?
    let age: String?
    let addressCityState: String?
    let addressCityStateList: [ExtractedAddress]?
    let relativesList: [String]?
    let profileUrl: ProfileUrl?
}

struct ExtractResult: Codable {
    let scrapedData: ScrapedData
    let result: Bool
    let score: Int
    let matchedFields: [String]
}

struct Metadata: Codable {
    let userData: UserData
    let extractResults: [ExtractResult]
}

struct AlertUI {
    var title: String = ""
    var description: String = ""

    static func noResults() -> AlertUI {
        AlertUI(title: "No results", description: "No results were found.")
    }

    static func finishedScanningAllBrokers() -> AlertUI {
        AlertUI(title: "Finished!", description: "We finished scanning all brokers. You should find the data inside ~/Desktop/PIR-Debug/")
    }

    static func from(error: DataBrokerProtectionError) -> AlertUI {
        AlertUI(title: error.title, description: error.description)
    }
}

final class NameUI: ObservableObject {
    let id = UUID()
    @Published var first: String
    @Published var middle: String
    @Published var last: String

    init(first: String, middle: String = "", last: String) {
        self.first = first
        self.middle = middle
        self.last = last
    }

    static func empty() -> NameUI {
        .init(first: "", middle: "", last: "")
    }

    func toModel() -> DataBrokerProtectionProfile.Name {
        .init(firstName: first, lastName: last, middleName: middle.isEmpty ? nil : middle)
    }
}

final class AddressUI: ObservableObject {
    let id = UUID()
    @Published var city: String
    @Published var state: String

    init(city: String, state: String) {
        self.city = city
        self.state = state
    }

    static func empty() -> AddressUI {
        .init(city: "", state: "")
    }

    func toModel() -> DataBrokerProtectionProfile.Address {
        .init(city: city, state: state)
    }
}

struct ScanResult {
    let id = UUID()
    let dataBroker: DataBroker
    let profileQuery: ProfileQuery
    let extractedProfile: ExtractedProfile
}

final class DataBrokerRunCustomJSONViewModel: ObservableObject {
    @Published var birthYear: String = ""
    @Published var results = [ScanResult]()
    @Published var showAlert = false
    @Published var showNoResults = false
    @Published var isRunningOnAllBrokers = false
    @Published var names = [NameUI.empty()]
    @Published var addresses = [AddressUI.empty()]

    var alert: AlertUI?
    var selectedDataBroker: DataBroker?
    var error: Error?

    let brokers: [DataBroker]

    private let runnerProvider: JobRunnerProvider
    private let privacyConfigManager: PrivacyConfigurationManaging
    private let fakePixelHandler: EventMapping<DataBrokerProtectionPixels> = EventMapping { event, _, _, _ in
        print(event)
    }
    private let contentScopeProperties: ContentScopeProperties
    private let csvColumns = ["name_input", "age_input", "city_input", "state_input", "name_scraped", "age_scraped", "address_scraped", "relatives_scraped", "url", "broker name", "screenshot_id", "error", "matched_fields", "result_match", "expected_match"]
    private let authenticationManager: DataBrokerProtectionAuthenticationManaging

    init(authenticationManager: DataBrokerProtectionAuthenticationManaging) {
        let privacyConfigurationManager = DBPPrivacyConfigurationManager()
        let features = ContentScopeFeatureToggles(emailProtection: false,
                                                  emailProtectionIncontextSignup: false,
                                                  credentialsAutofill: false,
                                                  identitiesAutofill: false,
                                                  creditCardsAutofill: false,
                                                  credentialsSaving: false,
                                                  passwordGeneration: false,
                                                  inlineIconCredentials: false,
                                                  thirdPartyCredentialsProvider: false,
                                                  unknownUsernameCategorization: false,
                                                  partialFormSaves: false)

        let sessionKey = UUID().uuidString
        let messageSecret = UUID().uuidString
        self.authenticationManager = authenticationManager
        let contentScopeProperties = ContentScopeProperties(gpcEnabled: false,
                                                            sessionKey: sessionKey,
                                                            messageSecret: messageSecret,
                                                            featureToggles: features)

        self.runnerProvider = DataBrokerJobRunnerProvider(
            privacyConfigManager: privacyConfigurationManager,
            contentScopeProperties: contentScopeProperties,
            emailService: EmailService(authenticationManager: authenticationManager),
            captchaService: CaptchaService(authenticationManager: authenticationManager))
        self.privacyConfigManager = privacyConfigurationManager
        self.contentScopeProperties = contentScopeProperties

        let fileResources = FileResources()
        self.brokers = (try? fileResources.fetchBrokerFromResourceFiles()) ?? [DataBroker]()
    }

    func runAllBrokers() {
        isRunningOnAllBrokers = true

        let brokerProfileQueryData = createBrokerProfileQueryData()

        Task.detached {
            var scanResults = [DebugScanReturnValue]()

            try await withThrowingTaskGroup(of: DebugScanReturnValue.self) { group in
                for queryData in brokerProfileQueryData {
                    let debugScanJob = DebugScanJob(privacyConfig: self.privacyConfigManager,
                                                    prefs: self.contentScopeProperties,
                                                    query: queryData,
                                                    emailService: EmailService(authenticationManager: self.authenticationManager),
                                                    captchaService: CaptchaService(authenticationManager: self.authenticationManager)) {
                        true
                    }

                    group.addTask {
                        do {
                            return try await debugScanJob.run(inputValue: (), showWebView: false)
                        } catch {
                            return DebugScanReturnValue(brokerURL: "ERROR - with broker: \(queryData.dataBroker.name)", extractedProfiles: [ExtractedProfile](), brokerProfileQueryData: queryData)
                        }
                    }
                }

                for try await result in group {
                    scanResults.append(result)
                }

                self.formCSV(with: scanResults)

                self.finishLoading()
            }
        }
    }

    private func finishLoading() {
        DispatchQueue.main.async {
            self.alert = AlertUI.finishedScanningAllBrokers()
            self.showAlert = true
            self.isRunningOnAllBrokers = false
        }
    }

    private func formCSV(with scanResults: [DebugScanReturnValue]) {
        var csvText = csvColumns.map { $0 }.joined(separator: ",")
        csvText.append("\n")

        for result in scanResults {
            if let error = result.error {
                csvText.append(append(error: error, for: result))
            } else {
                csvText.append(append(result))
            }
        }

        save(csv: csvText)
    }

    private func append(error: Error, for result: DebugScanReturnValue) -> String {
        if let dbpError = error as? DataBrokerProtectionError {
            if dbpError.is404 {
                return createRowFor(matched: false, result: result, error: "404 - No results")
            } else {
                return createRowFor(matched: false, result: result, error: "\(dbpError.title)-\(dbpError.description)")
            }
        } else {
            return createRowFor(matched: false, result: result, error: error.localizedDescription)
        }
    }

    private func append(_ result: DebugScanReturnValue) -> String {
        var resultsText = ""

        if let meta = result.meta{
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: meta, options: [])
                let decoder = JSONDecoder()
                let decodedMeta = try decoder.decode(Metadata.self, from: jsonData)

                for extractedResult in decodedMeta.extractResults {
                    resultsText.append(createRowFor(matched: extractedResult.result, result: result, extractedResult: extractedResult))
                }
            } catch {
                print("Error decoding JSON: \(error)")
            }
        } else {
            print("No meta object")
        }

        return resultsText
    }

    private func createRowFor(matched: Bool,
                              result: DebugScanReturnValue,
                              error: String? = nil,
                              extractedResult: ExtractResult? = nil) -> String {
        let matchedString = matched ? "TRUE" : "FALSE"
        let profileQuery = result.brokerProfileQueryData.profileQuery

        var csvRow = ""

        csvRow.append("\(profileQuery.fullName),") // Name (input)
        csvRow.append("\(profileQuery.age),") // Age (input)
        csvRow.append("\(profileQuery.city),") // City (input)
        csvRow.append("\(profileQuery.state),") // State (input)

        if let extractedResult = extractedResult {
            csvRow.append("\(extractedResult.scrapedData.nameCSV),") // Name (scraped)
            csvRow.append("\(extractedResult.scrapedData.ageCSV),") // Age (scraped)
            csvRow.append("\(extractedResult.scrapedData.addressesCSV),") // Address (scraped)
            csvRow.append("\(extractedResult.scrapedData.relativesCSV),") // Relatives (matched)
        } else {
            csvRow.append(",") // Name (scraped)
            csvRow.append(",") // Age (scraped)
            csvRow.append(",") // Address (scraped)
            csvRow.append(",") // Relatives (scraped)
        }

        csvRow.append("\(result.brokerURL),") // Broker URL
        csvRow.append("\(result.brokerProfileQueryData.dataBroker.name),") // Broker Name
        csvRow.append("\(profileQuery.id ?? 0)_\(result.brokerProfileQueryData.dataBroker.name),") // Screenshot name

        if let error = error {
            csvRow.append("\(error),") // Error
        } else {
            csvRow.append(",") // Error empty
        }

        if let extractedResult = extractedResult {
            csvRow.append("\(extractedResult.matchedFields.joined(separator: "-")),") // matched_fields
        } else {
            csvRow.append(",") // matched_fields
        }

        csvRow.append("\(matchedString),") // result_match
        csvRow.append(",") // expected_match
        csvRow.append("\n")

        return csvRow
    }

    private func save(csv: String) {
        do {
            if let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.relativePath {
                let path = desktopPath + "/PIR-Debug"
                let fileName = "output.csv"
                let fileURL = URL(fileURLWithPath: "\(path)/\(fileName)")
                try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            } else {
                Logger.dataBrokerProtection.error("Error getting path")
            }
        } catch {
            Logger.dataBrokerProtection.error("Error writing to file: \(error)")
        }
    }

    @MainActor
    func runJSON(jsonString: String) {
        self.error = nil
        if let data = jsonString.data(using: .utf8) {
            do {
                let decoder = JSONDecoder()
                let dataBroker = try decoder.decode(DataBroker.self, from: data)
                self.selectedDataBroker = dataBroker
                let brokerProfileQueryData = createBrokerProfileQueryData(for: dataBroker)
                let runner = runnerProvider.getJobRunner()
                let group = DispatchGroup()

                for query in brokerProfileQueryData {
                    group.enter()

                    Task {
                        do {
                            let extractedProfiles = try await runner.scan(query, stageCalculator: FakeStageDurationCalculator(), pixelHandler: fakePixelHandler, showWebView: true) { true }

                            DispatchQueue.main.async {
                                for extractedProfile in extractedProfiles {
                                    self.results.append(ScanResult(dataBroker: query.dataBroker,
                                                                   profileQuery: query.profileQuery,
                                                                   extractedProfile: extractedProfile))
                                }
                            }
                            group.leave()
                        } catch {
                            self.error = error
                            group.leave()
                        }
                    }
                }
                group.notify(queue: .main) {
                    if let error = self.error {
                        self.showAlert(for: error)
                    } else if self.results.count == 0 {
                        self.showNoResultsAlert()
                    }
                }
            } catch {
                showAlert(for: error)
            }
        }
    }

    @MainActor
    func runOptOut(scanResult: ScanResult) {
        let runner = runnerProvider.getJobRunner()
        let brokerProfileQueryData = BrokerProfileQueryData(
            dataBroker: scanResult.dataBroker,
            profileQuery: scanResult.profileQuery,
            scanJobData: ScanJobData(brokerId: 1, profileQueryId: 1, historyEvents: [HistoryEvent]())
        )
        Task {
            do {
                try await runner.optOut(profileQuery: brokerProfileQueryData, extractedProfile: scanResult.extractedProfile, stageCalculator: FakeStageDurationCalculator(), pixelHandler: fakePixelHandler, showWebView: true) {
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

    private func createBrokerProfileQueryData(for broker: DataBroker) -> [BrokerProfileQueryData] {
        let profile: DataBrokerProtectionProfile =
            .init(
                names: names.map { $0.toModel() },
                addresses: addresses.map { $0.toModel() },
                phones: [String](),
                birthYear: Int(birthYear) ?? 1990
            )
        let profileQueries = profile.profileQueries
        var brokerProfileQueryData = [BrokerProfileQueryData]()

        var profileQueryIndex: Int64 = 1
        for profileQuery in profileQueries {
            let fakeScanJobData = ScanJobData(brokerId: 0, profileQueryId: profileQueryIndex, historyEvents: [HistoryEvent]())
            brokerProfileQueryData.append(
                .init(dataBroker: broker, profileQuery: profileQuery.with(id: profileQueryIndex), scanJobData: fakeScanJobData)
            )

            profileQueryIndex += 1
        }

        return brokerProfileQueryData
    }

    private func createBrokerProfileQueryData() -> [BrokerProfileQueryData] {
        let profile: DataBrokerProtectionProfile =
            .init(
                names: names.map { $0.toModel() },
                addresses: addresses.map { $0.toModel() },
                phones: [String](),
                birthYear: Int(birthYear) ?? 1990
            )
        let profileQueries = profile.profileQueries
        var brokerProfileQueryData = [BrokerProfileQueryData]()

        var profileQueryIndex: Int64 = 1
        for profileQuery in profileQueries {
            let fakeScanJobData = ScanJobData(brokerId: 0, profileQueryId: profileQueryIndex, historyEvents: [HistoryEvent]())
            for broker in brokers {
                brokerProfileQueryData.append(
                    .init(dataBroker: broker, profileQuery: profileQuery.with(id: profileQueryIndex), scanJobData: fakeScanJobData)
                )
            }

            profileQueryIndex += 1
        }

        return brokerProfileQueryData
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

    func appVersion() -> String {
        AppVersion.shared.versionNumber
    }
}

final class FakeSleepObserver: SleepObserver {

    func totalSleepTime() -> TimeInterval {
        return 0
    }
}

final class FakeStageDurationCalculator: StageDurationCalculator {
    var attemptId: UUID = UUID()
    var isImmediateOperation: Bool = false

    func durationSinceLastStage() -> Double {
        0.0
    }

    func durationSinceStartTime() -> Double {
        0.0
    }

    func fireOptOutStart() {
    }

    func setEmailPattern(_ emailPattern: String?) {
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

    func fireOptOutFillForm() {
    }

    func fireOptOutValidate() {
    }

    func fireOptOutSubmitSuccess(tries: Int) {
    }

    func fireOptOutFailure(tries: Int) {
    }

    func fireScanSuccess(matchesFound: Int) {
    }

    func fireScanFailed() {
    }

    func fireScanError(error: Error) {
    }

    func setStage(_ stage: Stage) {
    }

    func setLastActionId(_ actionID: String) {
    }
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
                return "No results (404)"
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
                return "No results were found. (404 was returned)"
            } else {
                return "Failed with HTTP error code: \(code)"
            }
        default: return name
        }
    }

    var is404: Bool {
        switch self {
        case .httpError(let code):
            return code == 404
        default: return false
        }
    }
}

extension ScrapedData {

    var nameCSV: String {
        if let name = self.name {
            return name.replacingOccurrences(of: ",", with: "-")
        } else if let alternativeNamesList = self.alternativeNamesList {
            return alternativeNamesList.joined(separator: "/").replacingOccurrences(of: ",", with: "-")
        } else {
            return ""
        }
    }

    var ageCSV: String {
        if let age = self.age {
            return age
        } else {
            return ""
        }
    }

    var addressesCSV: String {
        if let address = self.addressCityState {
            return address
        } else if let addressFull = self.addressCityStateList {
            return addressFull.map { "\($0.city)-\($0.state)" }.joined(separator: "/")
        } else {
            return ""
        }
    }

    var relativesCSV: String {
        if let relatives = self.relativesList {
            return relatives.joined(separator: "-").replacingOccurrences(of: ",", with: "-")
        } else {
            return ""
        }
    }
}
