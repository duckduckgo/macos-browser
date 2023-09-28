//
//  Mocks.swift
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
import BrowserServicesKit
import Common
import SecureStorage
import GRDB
@testable import DataBrokerProtection

extension BrokerProfileQueryData {
    static func mock(with steps: [Step] = [Step]()) -> BrokerProfileQueryData {
        BrokerProfileQueryData(
            dataBroker: DataBroker(
                name: "test",
                steps: steps,
                version: "1.0.0",
                schedulingConfig: DataBrokerScheduleConfig.mock
            ),
            profileQuery: ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", birthYear: 50),
            scanOperationData: ScanOperationData(brokerId: 1, profileQueryId: 1, historyEvents: [HistoryEvent]())
        )
    }
}

extension DataBrokerScheduleConfig {
    static var mock: DataBrokerScheduleConfig {
        DataBrokerScheduleConfig(retryError: 1, confirmOptOutScan: 2, maintenanceScan: 3)
    }
}

final class PrivacyConfigurationManagingMock: PrivacyConfigurationManaging {
    var currentConfig: Data = Data()

    var updatesPublisher: AnyPublisher<Void, Never> = .init(Just(()))

    var privacyConfig: BrowserServicesKit.PrivacyConfiguration = PrivacyConfigurationMock()

    func reload(etag: String?, data: Data?) -> PrivacyConfigurationManager.ReloadResult {
        .downloaded
    }
}

final class PrivacyConfigurationMock: PrivacyConfiguration {
    var identifier: String = "mock"

    var userUnprotectedDomains = [String]()

    var tempUnprotectedDomains = [String]()

    var trackerAllowlist = BrowserServicesKit.PrivacyConfigurationData.TrackerAllowlist(entries: [String: [PrivacyConfigurationData.TrackerAllowlist.Entry]](), state: "mock")

    func isEnabled(featureKey: BrowserServicesKit.PrivacyFeature, versionProvider: BrowserServicesKit.AppVersionProvider) -> Bool {
        false
    }

    func isSubfeatureEnabled(_ subfeature: any PrivacySubfeature, versionProvider: BrowserServicesKit.AppVersionProvider) -> Bool {
        false
    }

    func exceptionsList(forFeature featureKey: BrowserServicesKit.PrivacyFeature) -> [String] {
        [String]()
    }

    func isFeature(_ feature: BrowserServicesKit.PrivacyFeature, enabledForDomain: String?) -> Bool {
        false
    }

    func isProtected(domain: String?) -> Bool {
        false
    }

    func isUserUnprotected(domain: String?) -> Bool {
        false
    }

    func isTempUnprotected(domain: String?) -> Bool {
        false
    }

    func isInExceptionList(domain: String?, forFeature featureKey: BrowserServicesKit.PrivacyFeature) -> Bool {
        false
    }

    func settings(for feature: BrowserServicesKit.PrivacyFeature) -> BrowserServicesKit.PrivacyConfigurationData.PrivacyFeature.FeatureSettings {
        [String: Any]()
    }

    func userEnabledProtection(forDomain: String) {

    }

    func userDisabledProtection(forDomain: String) {

    }

    func isSubfeatureEnabled(_ subfeature: any BrowserServicesKit.PrivacySubfeature, versionProvider: BrowserServicesKit.AppVersionProvider, randomizer: (Range<Double>) -> Double) -> Bool {
        false
    }
}

extension ContentScopeProperties {
    static var mock: ContentScopeProperties {
        ContentScopeProperties(
            gpcEnabled: false,
            sessionKey: "sessionKey",
            featureToggles: ContentScopeFeatureToggles.mock
        )
    }
}

extension ContentScopeFeatureToggles {

    static var mock: ContentScopeFeatureToggles {
        ContentScopeFeatureToggles(
            emailProtection: false,
            emailProtectionIncontextSignup: false,
            credentialsAutofill: false,
            identitiesAutofill: false,
            creditCardsAutofill: false,
            credentialsSaving: false,
            passwordGeneration: false,
            inlineIconCredentials: false,
            thirdPartyCredentialsProvider: false
        )
    }
}

final class WebViewHandlerMock: NSObject, WebViewHandler {
    var wasInitializeWebViewCalled = false
    var wasLoadCalledWithURL: URL?
    var wasWaitForWebViewLoadCalled = false
    var wasFinishCalled = false
    var wasExecuteCalledForExtractedProfile = false
    var wasExecuteCalledForProfileData = false
    var wasExecuteCalledForSolveCaptcha = false
    var wasExecuteJavascriptCalled = false

    func initializeWebView(showWebView: Bool) async {
        wasInitializeWebViewCalled = true
    }

    func load(url: URL) async throws {
        wasLoadCalledWithURL = url
    }

    func waitForWebViewLoad(timeoutInSeconds: Int) async throws {
        wasWaitForWebViewLoadCalled = true
    }

    func finish() async {
        wasFinishCalled = true
    }

    func execute(action: DataBrokerProtection.Action, data: DataBrokerProtection.CCFRequestData) async {
        switch data {
        case .profile:
            wasExecuteCalledForExtractedProfile = false
            wasExecuteCalledForSolveCaptcha = false
            wasExecuteCalledForProfileData = true
        case .solveCaptcha:
            wasExecuteCalledForExtractedProfile = false
            wasExecuteCalledForSolveCaptcha = true
            wasExecuteCalledForProfileData = false
        case.extractedProfile:
            wasExecuteCalledForExtractedProfile = true
            wasExecuteCalledForSolveCaptcha = false
            wasExecuteCalledForProfileData = false
        }
    }

    func evaluateJavaScript(_ javaScript: String) async throws {
        wasExecuteJavascriptCalled = true
    }

    func reset() {
        wasInitializeWebViewCalled = false
        wasLoadCalledWithURL = nil
        wasWaitForWebViewLoadCalled = false
        wasFinishCalled = false
        wasExecuteCalledForExtractedProfile = false
        wasExecuteCalledForSolveCaptcha = false
        wasExecuteCalledForProfileData = false
        wasExecuteJavascriptCalled = false
    }
}

final class EmailServiceMock: EmailServiceProtocol {

    var shouldThrow: Bool = false

    func getEmail() async throws -> String {
        if shouldThrow {
            throw DataBrokerProtectionError.emailError(nil)
        }

        return "test@duck.com"
    }

    func getConfirmationLink(from email: String, numberOfRetries: Int, pollingIntervalInSeconds: Int, shouldRunNextStep: @escaping () -> Bool) async throws -> URL {
        if shouldThrow {
            throw DataBrokerProtectionError.emailError(nil)
        }

        return URL(string: "https://www.duckduckgo.com")!
    }

    func reset() {
        shouldThrow = false
    }
}

final class CaptchaServiceMock: CaptchaServiceProtocol {

    var wasSubmitCaptchaInformationCalled = false
    var wasSubmitCaptchaToBeResolvedCalled = false
    var shouldThrow = false

    func submitCaptchaInformation(_ captchaInfo: GetCaptchaInfoResponse, retries: Int, shouldRunNextStep: @escaping () -> Bool) async throws -> CaptchaTransactionId {
        if shouldThrow {
            throw CaptchaServiceError.errorWhenSubmittingCaptcha
        }

        wasSubmitCaptchaInformationCalled = true

        return "transactionID"
    }

    func submitCaptchaToBeResolved(for transactionID: CaptchaTransactionId, retries: Int, pollingInterval: Int, shouldRunNextStep: @escaping () -> Bool) async throws -> CaptchaResolveData {
        if shouldThrow {
            throw CaptchaServiceError.errorWhenFetchingCaptchaResult
        }

        wasSubmitCaptchaToBeResolvedCalled = true

        return CaptchaResolveData()
    }

    func reset() {
        wasSubmitCaptchaInformationCalled = false
        wasSubmitCaptchaToBeResolvedCalled = false
    }
}

final class MockRedeemUseCase: DataBrokerProtectionRedeemUseCase {

    func shouldAskForInviteCode() -> Bool {
        false
    }

    func redeem(inviteCode: String) async throws {

    }

    func getAuthHeader() async throws -> String {
        return "auth header"
    }
}

final class MockAuthenticationService: DataBrokerProtectionAuthenticationService {

    var wasRedeemCalled = false
    var shouldThrow = false

    func redeem(inviteCode: String) async throws -> String {
        wasRedeemCalled = true
        if shouldThrow {
            throw AuthenticationError.issueRedeemingInviteCode(error: "mock")
        }

        return "accessToken"
    }

    func reset() {
        wasRedeemCalled = false
        shouldThrow = false
    }
}

final class MockAuthenticationRepository: AuthenticationRepository {

    var shouldSendNilInviteCode = false
    var shouldSendNilAccessToken = false
    var wasInviteCodeSaveCalled = false
    var wasAccessTokenSaveCalled = false

    func getInviteCode() -> String? {
        if shouldSendNilInviteCode {
            return nil
        }

        return "inviteCode"
    }

    func getAccessToken() -> String? {
        if shouldSendNilAccessToken {
            return nil
        }

        return "accessToken"
    }

    func save(inviteCode: String) {
        wasInviteCodeSaveCalled = true
    }

    func save(accessToken: String) {
        wasAccessTokenSaveCalled = true
    }

    func reset() {
        shouldSendNilInviteCode = false
        shouldSendNilAccessToken = false
        wasInviteCodeSaveCalled = false
        wasAccessTokenSaveCalled = false
    }
}

final class BrokerUpdaterRepositoryMock: BrokerUpdaterRepository {
    var wasSaveLastRunDateCalled = false
    var lastRunDate: Date?

    func saveLastRunDate(date: Date) {
        wasSaveLastRunDateCalled = true
    }

    func getLastRunDate() -> Date? {
        return lastRunDate
    }

    func reset() {
        wasSaveLastRunDateCalled = false
        lastRunDate = nil
    }
}

final class ResourcesRepositoryMock: ResourcesRepository {
    var wasFetchBrokerFromResourcesFilesCalled = false
    var brokersList: [DataBroker]?

    func fetchBrokerFromResourceFiles() -> [DataBroker]? {
        wasFetchBrokerFromResourcesFilesCalled = true
        return brokersList
    }

    func reset() {
        wasFetchBrokerFromResourcesFilesCalled = false
        brokersList?.removeAll()
        brokersList = nil
    }
}

final class EmptySecureStorageKeyStoreProviderMock: SecureStorageKeyStoreProvider {
    var generatedPasswordEntryName: String = ""

    var l1KeyEntryName: String = ""

    var l2KeyEntryName: String = ""

    var keychainServiceName: String = ""

    func attributesForEntry(named: String, serviceName: String) -> [String: Any] {
        return [String: Any]()
    }
}

final class EmptySecureStorageCryptoProviderMock: SecureStorageCryptoProvider {
    var passwordSalt: Data = Data()

    var keychainServiceName: String = ""

    var keychainAccountName: String = ""
}

final class SecureStorageDatabaseProviderMock: SecureStorageDatabaseProvider {
    let db: DatabaseWriter

    init() throws {
        do {
            self.db = try DatabaseQueue()
        } catch {
            throw DataBrokerProtectionError.unknown("")
        }
    }
}

final class DataBrokerProtectionSecureVaultMock: DataBrokerProtectionSecureVault {
    func fetchAttemptInformation(for extractedProfileId: Int64) throws -> AttemptInformation? {
        return nil
    }

    func save(extractedProfileId: Int64, attemptUUID: UUID, dataBroker: String, lastStageDate: Date, startTime: Date) throws {
    }

    var shouldReturnOldVersionBroker = false
    var shouldReturnNewVersionBroker = false
    var wasBrokerUpdateCalled = false
    var wasBrokerSavedCalled = false

    typealias DatabaseProvider = SecureStorageDatabaseProviderMock

    required init(providers: SecureStorageProviders<SecureStorageDatabaseProviderMock>) {
    }

    func reset() {
        shouldReturnOldVersionBroker = false
        shouldReturnNewVersionBroker = false
        wasBrokerUpdateCalled = false
        wasBrokerSavedCalled = false
    }

    func save(profile: DataBrokerProtectionProfile) throws -> Int64 {
        return 1
    }

    func fetchProfile(with id: Int64) throws -> DataBrokerProtectionProfile? {
        return nil
    }

    func save(broker: DataBroker) throws -> Int64 {
        wasBrokerSavedCalled = true
        return 1
    }

    func update(_ broker: DataBroker, with id: Int64) throws {
        wasBrokerUpdateCalled = true
    }

    func fetchBroker(with id: Int64) throws -> DataBroker? {
        return nil
    }

    func fetchBroker(with name: String) throws -> DataBroker? {
        if shouldReturnOldVersionBroker {
            return .init(id: 1, name: "Broker", steps: [Step](), version: "1.0.0", schedulingConfig: .mock)
        } else if shouldReturnNewVersionBroker {
            return .init(id: 1, name: "Broker", steps: [Step](), version: "1.0.1", schedulingConfig: .mock)
        }

        return nil
    }

    func fetchAllBrokers() throws -> [DataBroker] {
        return [DataBroker]()
    }

    func save(profileQuery: ProfileQuery, profileId: Int64) throws -> Int64 {
        return 1
    }

    func fetchProfileQuery(with id: Int64) throws -> ProfileQuery? {
        return nil
    }

    func fetchAllProfileQueries(for profileId: Int64) throws -> [ProfileQuery] {
        return [ProfileQuery]()
    }

    func save(brokerId: Int64, profileQueryId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws {

    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws {
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws {
    }

    func fetchScan(brokerId: Int64, profileQueryId: Int64) throws -> ScanOperationData? {
        return nil
    }

    func fetchAllScans() throws -> [ScanOperationData] {
        return [ScanOperationData]()
    }

    func save(brokerId: Int64, profileQueryId: Int64, extractedProfile: ExtractedProfile, lastRunDate: Date?, preferredRunDate: Date?) throws {
    }

    func save(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws {
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
    }

    func fetchOptOut(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws -> OptOutOperationData? {
        return nil
    }

    func fetchOptOuts(brokerId: Int64, profileQueryId: Int64) throws -> [OptOutOperationData] {
        return [OptOutOperationData]()
    }

    func fetchAllOptOuts() throws -> [OptOutOperationData] {
        return [OptOutOperationData]()
    }

    func save(historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64) throws {
    }

    func save(historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
    }

    func fetchEvents(brokerId: Int64, profileQueryId: Int64) throws -> [HistoryEvent] {
        return [HistoryEvent]()
    }

    func save(extractedProfile: ExtractedProfile, brokerId: Int64, profileQueryId: Int64) throws -> Int64 {
        return 1
    }

    func fetchExtractedProfile(with id: Int64) throws -> ExtractedProfile? {
        return nil
    }

    func fetchExtractedProfiles(for brokerId: Int64, with profileQueryId: Int64) throws -> [ExtractedProfile] {
        return [ExtractedProfile]()
    }

    func fetchExtractedProfiles(for brokerId: Int64) throws -> [ExtractedProfile] {
        return [ExtractedProfile]()
    }

    func updateRemovedDate(for extractedProfileId: Int64, with date: Date?) throws {
    }

    func hasMatches() throws -> Bool {
        false
    }

    func fetchChildBrokers(for parentBroker: String) throws -> [DataBroker] {
        return [DataBroker]()
    }
}

public class MockDataBrokerProtectionPixelsHandler: EventMapping<DataBrokerProtectionPixels> {

    // swiftlint:disable:next cyclomatic_complexity
    public init() {
        super.init { event, _, _, _ in
            switch event {
            case .error(let error, _):
                print("PIXEL: Error: \(error)")
            case .optOutStart:
                print("PIXEL: optOutStart")
            case .optOutEmailGenerate:
                print("PIXEL: optOutEmailGenerate")
            case .optOutCaptchaParse:
                print("PIXEL: optOutCaptchaParse")
            case .optOutCaptchaSend:
                print("PIXEL: optOutCaptchaSend")
            case .optOutCaptchaSolve:
                print("PIXEL: optOutCaptchaSolve")
            case .optOutSubmit:
                print("PIXEL: optOutSubmit")
            case .optOutEmailReceive:
                print("PIXEL: optOutEmailReceive")
            case .optOutEmailConfirm:
                print("PIXEL: optOutEmailConfirm")
            case .optOutValidate:
                print("PIXEL: optOutValidate")
            case .optOutFinish:
                print("PIXEL: optOutFinish")
            case .optOutSuccess:
                print("PIXEL: optOutSuccess")
            case .optOutFailure:
                print("PIXEL: optOutFailure")
            }
        }
    }

    override init(mapping: @escaping EventMapping<DataBrokerProtectionPixels>.Mapping) {
        fatalError("Use init()")
    }
}
