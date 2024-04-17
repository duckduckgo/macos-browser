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

import BrowserServicesKit
import Combine
import Common
import Foundation
import GRDB
import SecureStorage

@testable import DataBrokerProtection

extension BrokerProfileQueryData {
    static func mock(with steps: [Step] = [Step](),
                     dataBrokerName: String = "test",
                     url: String = "test.com",
                     lastRunDate: Date? = nil,
                     preferredRunDate: Date? = nil,
                     extractedProfile: ExtractedProfile? = nil,
                     scanHistoryEvents: [HistoryEvent] = [HistoryEvent](),
                     mirrorSites: [MirrorSite] = [MirrorSite](),
                     deprecated: Bool = false) -> BrokerProfileQueryData {
        BrokerProfileQueryData(
            dataBroker: DataBroker(
                name: dataBrokerName,
                url: url,
                steps: steps,
                version: "1.0.0",
                schedulingConfig: DataBrokerScheduleConfig.mock,
                mirrorSites: mirrorSites
            ),
            profileQuery: ProfileQuery(firstName: "John", lastName: "Doe", city: "Miami", state: "FL", birthYear: 50, deprecated: deprecated),
            scanOperationData: ScanOperationData(brokerId: 1,
                                                 profileQueryId: 1,
                                                 preferredRunDate: preferredRunDate,
                                                 historyEvents: scanHistoryEvents,
                                                 lastRunDate: lastRunDate),
            optOutOperationsData: extractedProfile != nil ? [.mock(with: extractedProfile!)] : [OptOutOperationData]()
        )
    }
}

extension DataBrokerScheduleConfig {
    static var mock: DataBrokerScheduleConfig {
        DataBrokerScheduleConfig(retryError: 1, confirmOptOutScan: 2, maintenanceScan: 3)
    }
}

final class InternalUserDeciderStoreMock: InternalUserStoring {
    var isInternalUser: Bool = false
}

final class PrivacyConfigurationManagingMock: PrivacyConfigurationManaging {
    var toggleProtectionsCounter: ToggleProtectionsCounter = ToggleProtectionsCounter(eventReporting: nil)

    var currentConfig: Data = Data()

    var updatesPublisher: AnyPublisher<Void, Never> = .init(Just(()))

    var privacyConfig: BrowserServicesKit.PrivacyConfiguration = PrivacyConfigurationMock()

    var internalUserDecider: InternalUserDecider = DefaultInternalUserDecider(store: InternalUserDeciderStoreMock())

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

    func stateFor(featureKey: BrowserServicesKit.PrivacyFeature, versionProvider: BrowserServicesKit.AppVersionProvider) -> BrowserServicesKit.PrivacyConfigurationFeatureState {
        .disabled(.disabledInConfig)
    }

    func isSubfeatureEnabled(_ subfeature: any PrivacySubfeature, versionProvider: BrowserServicesKit.AppVersionProvider) -> Bool {
        false
    }

    func stateFor(_ subfeature: any PrivacySubfeature, versionProvider: BrowserServicesKit.AppVersionProvider, randomizer: (Range<Double>) -> Double) -> BrowserServicesKit.PrivacyConfigurationFeatureState {
        .disabled(.disabledInConfig)
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
    var wasExecuteCalledForUserData = false
    var wasExecuteCalledForSolveCaptcha = false
    var wasExecuteJavascriptCalled = false
    var wasSetCookiesCalled = false

    func initializeWebView(showWebView: Bool) async {
        wasInitializeWebViewCalled = true
    }

    func load(url: URL) async throws {
        wasLoadCalledWithURL = url
    }

    func waitForWebViewLoad() async throws {
        wasWaitForWebViewLoadCalled = true
    }

    func finish() async {
        wasFinishCalled = true
    }

    func execute(action: DataBrokerProtection.Action, data: DataBrokerProtection.CCFRequestData) async {
        switch data {
        case .solveCaptcha:
            wasExecuteCalledForSolveCaptcha = true
            wasExecuteCalledForUserData = false
        case .userData:
            wasExecuteCalledForUserData = true
            wasExecuteCalledForSolveCaptcha = false
        }
    }

    func evaluateJavaScript(_ javaScript: String) async throws {
        wasExecuteJavascriptCalled = true
    }

    func takeSnaphost(path: String, fileName: String) async throws {

    }

    func saveHTML(path: String, fileName: String) async throws {

    }

    func setCookies(_ cookies: [HTTPCookie]) async {
        wasSetCookiesCalled = true
    }

    func reset() {
        wasInitializeWebViewCalled = false
        wasLoadCalledWithURL = nil
        wasWaitForWebViewLoadCalled = false
        wasFinishCalled = false
        wasExecuteCalledForSolveCaptcha = false
        wasExecuteJavascriptCalled = false
        wasExecuteCalledForUserData = false
        wasSetCookiesCalled = false
    }
}

final class MockCookieHandler: CookieHandler {
    var cookiesToReturn: [HTTPCookie]?

    func getAllCookiesFromDomain(_ url: URL) async -> [HTTPCookie]? {
        return cookiesToReturn
    }

    func clear() {
        cookiesToReturn = nil
    }
}

final class EmailServiceMock: EmailServiceProtocol {

    var shouldThrow: Bool = false

    func getEmail(dataBrokerURL: String, attemptId: UUID) async throws -> EmailData {
        if shouldThrow {
            throw DataBrokerProtectionError.emailError(nil)
        }

        return EmailData(pattern: nil, emailAddress: "test@duck.com")
    }

    func getConfirmationLink(from email: String, numberOfRetries: Int, pollingInterval: TimeInterval, attemptId: UUID, shouldRunNextStep: @escaping () -> Bool) async throws -> URL {
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

    func submitCaptchaInformation(_ captchaInfo: GetCaptchaInfoResponse, retries: Int, pollingInterval: TimeInterval, attemptId: UUID, shouldRunNextStep: @escaping () -> Bool) async throws -> CaptchaTransactionId {
        if shouldThrow {
            throw CaptchaServiceError.errorWhenSubmittingCaptcha
        }

        wasSubmitCaptchaInformationCalled = true

        return "transactionID"
    }

    func submitCaptchaToBeResolved(for transactionID: CaptchaTransactionId, retries: Int, pollingInterval: TimeInterval, attemptId: UUID, shouldRunNextStep: @escaping () -> Bool) async throws -> CaptchaResolveData {
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
    var shouldSendNilAuthHeader = false

    func getAuthHeader() -> String? {
        if shouldSendNilAuthHeader {
            return nil
        }
        return "auth header"
    }

    func shouldAskForInviteCode() -> Bool {
        false
    }

    func redeem(inviteCode: String) async throws {

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

    func getWaitlistTimestamp() -> Int? {
        123
    }

    func reset() {
        shouldSendNilInviteCode = false
        shouldSendNilAccessToken = false
        wasInviteCodeSaveCalled = false
        wasAccessTokenSaveCalled = false
    }
}

final class BrokerUpdaterRepositoryMock: BrokerUpdaterRepository {
    var wasSaveLatestAppVersionCheckCalled = false
    var lastCheckedVersion: String?

    func saveLatestAppVersionCheck(version: String) {
        wasSaveLatestAppVersionCheckCalled = true
    }

    func getLastCheckedVersion() -> String? {
        return lastCheckedVersion
    }

    func reset() {
        wasSaveLatestAppVersionCheckCalled = false
        lastCheckedVersion = nil
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

    var shouldReturnOldVersionBroker = false
    var shouldReturnNewVersionBroker = false
    var wasBrokerUpdateCalled = false
    var wasBrokerSavedCalled = false
    var wasUpdateProfileQueryCalled = false
    var wasDeleteProfileQueryCalled = false
    var wasSaveProfileQueryCalled = false
    var profile: DataBrokerProtectionProfile?
    var profileQueries = [ProfileQuery]()
    var brokers = [DataBroker]()
    var scanOperationData = [ScanOperationData]()
    var optOutOperationData = [OptOutOperationData]()
    var lastPreferredRunDateOnScan: Date?

    typealias DatabaseProvider = SecureStorageDatabaseProviderMock

    required init(providers: SecureStorageProviders<SecureStorageDatabaseProviderMock>) {
    }

    func reset() {
        shouldReturnOldVersionBroker = false
        shouldReturnNewVersionBroker = false
        wasBrokerUpdateCalled = false
        wasBrokerSavedCalled = false
        wasUpdateProfileQueryCalled = false
        wasDeleteProfileQueryCalled = false
        wasSaveProfileQueryCalled = false
        profile = nil
        profileQueries.removeAll()
        brokers.removeAll()
        scanOperationData.removeAll()
        optOutOperationData.removeAll()
        lastPreferredRunDateOnScan = nil
    }

    func save(profile: DataBrokerProtectionProfile) throws -> Int64 {
        return 1
    }

    func fetchProfile(with id: Int64) throws -> DataBrokerProtectionProfile? {
        profile
    }

    func deleteProfileData() throws {
        return
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
            return .init(id: 1, name: "Broker", url: "broker.com", steps: [Step](), version: "1.0.0", schedulingConfig: .mock)
        } else if shouldReturnNewVersionBroker {
            return .init(id: 1, name: "Broker", url: "broker.com", steps: [Step](), version: "1.0.1", schedulingConfig: .mock)
        }

        return nil
    }

    func fetchAllBrokers() throws -> [DataBroker] {
        return brokers
    }

    func save(profileQuery: ProfileQuery, profileId: Int64) throws -> Int64 {
        wasSaveProfileQueryCalled = true
        return 1
    }

    func fetchProfileQuery(with id: Int64) throws -> ProfileQuery? {
        return nil
    }

    func fetchAllProfileQueries(for profileId: Int64) throws -> [ProfileQuery] {
        return profileQueries
    }

    func save(brokerId: Int64, profileQueryId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws {
        lastPreferredRunDateOnScan = preferredRunDate
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws {
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) throws {
    }

    func fetchScan(brokerId: Int64, profileQueryId: Int64) throws -> ScanOperationData? {
        scanOperationData.first
    }

    func fetchAllScans() throws -> [ScanOperationData] {
        return scanOperationData
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
        optOutOperationData.first
    }

    func fetchOptOuts(brokerId: Int64, profileQueryId: Int64) throws -> [OptOutOperationData] {
        return optOutOperationData
    }

    func fetchAllOptOuts() throws -> [OptOutOperationData] {
        return optOutOperationData
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

    func update(profile: DataBrokerProtection.DataBrokerProtectionProfile) throws -> Int64 {
        return 1
    }

    func delete(profileQuery: DataBrokerProtection.ProfileQuery, profileId: Int64) throws {
        wasDeleteProfileQueryCalled = true
    }

    func update(_ profileQuery: DataBrokerProtection.ProfileQuery, brokerIDs: [Int64], profileId: Int64) throws -> Int64 {
        wasUpdateProfileQueryCalled = true
        return 1
    }

    func fetchAttemptInformation(for extractedProfileId: Int64) throws -> AttemptInformation? {
        return nil
    }

    func save(extractedProfileId: Int64, attemptUUID: UUID, dataBroker: String, lastStageDate: Date, startTime: Date) throws {
    }
}

public class MockDataBrokerProtectionPixelsHandler: EventMapping<DataBrokerProtectionPixels> {

    static var lastPixelsFired = [DataBrokerProtectionPixels]()

    public init() {
        super.init { event, _, _, _ in
            MockDataBrokerProtectionPixelsHandler.lastPixelsFired.append(event)
        }
    }

    override init(mapping: @escaping EventMapping<DataBrokerProtectionPixels>.Mapping) {
        fatalError("Use init()")
    }

    func clear() {
        MockDataBrokerProtectionPixelsHandler.lastPixelsFired.removeAll()
    }
}

final class MockDatabase: DataBrokerProtectionRepository {
    var wasSaveProfileCalled = false
    var wasFetchProfileCalled = false
    var wasDeleteProfileDataCalled = false
    var wasSaveOptOutOperationCalled = false
    var wasBrokerProfileQueryDataCalled = false
    var wasFetchAllBrokerProfileQueryDataCalled = false
    var wasUpdatedPreferredRunDateForScanCalled = false
    var wasUpdatedPreferredRunDateForOptOutCalled = false
    var wasUpdateLastRunDateForScanCalled = false
    var wasUpdateLastRunDateForOptOutCalled = false
    var wasUpdateRemoveDateCalled = false
    var wasAddHistoryEventCalled = false
    var wasFetchLastHistoryEventCalled = false

    var eventsAdded = [HistoryEvent]()
    var lastHistoryEventToReturn: HistoryEvent?
    var lastPreferredRunDateOnScan: Date?
    var lastPreferredRunDateOnOptOut: Date?
    var extractedProfileRemovedDate: Date?
    var extractedProfilesFromBroker = [ExtractedProfile]()
    var childBrokers = [DataBroker]()
    var lastParentBrokerWhereChildSitesWhereFetched: String?
    var lastProfileQueryIdOnScanUpdatePreferredRunDate: Int64?
    var brokerProfileQueryDataToReturn = [BrokerProfileQueryData]()
    var profile: DataBrokerProtectionProfile?
    var attemptInformation: AttemptInformation?
    var historyEvents = [HistoryEvent]()

    lazy var callsList: [Bool] = [
        wasSaveProfileCalled,
        wasFetchProfileCalled,
        wasDeleteProfileDataCalled,
        wasSaveOptOutOperationCalled,
        wasBrokerProfileQueryDataCalled,
        wasFetchAllBrokerProfileQueryDataCalled,
        wasUpdatedPreferredRunDateForScanCalled,
        wasUpdatedPreferredRunDateForOptOutCalled,
        wasUpdateLastRunDateForScanCalled,
        wasUpdateLastRunDateForOptOutCalled,
        wasUpdateRemoveDateCalled,
        wasAddHistoryEventCalled,
        wasFetchLastHistoryEventCalled]

    var wasDatabaseCalled: Bool {
        callsList.filter { $0 }.count > 0 // If one value is true. The database was called
    }

    func save(_ profile: DataBrokerProtectionProfile) throws {
        wasSaveProfileCalled = true
    }

    func fetchProfile() -> DataBrokerProtectionProfile? {
        wasFetchProfileCalled = true
        return profile
    }

    func setFetchedProfile(_ profile: DataBrokerProtectionProfile?) {
        self.profile = profile
    }

    func deleteProfileData() {
        wasDeleteProfileDataCalled = true
    }

    func saveOptOutOperation(optOut: OptOutOperationData, extractedProfile: ExtractedProfile) throws {
        wasSaveOptOutOperationCalled = true
    }

    func brokerProfileQueryData(for brokerId: Int64, and profileQueryId: Int64) -> BrokerProfileQueryData? {
        wasBrokerProfileQueryDataCalled = true

        if !brokerProfileQueryDataToReturn.isEmpty {
            return brokerProfileQueryDataToReturn.first
        }

        if let lastHistoryEventToReturn = self.lastHistoryEventToReturn {
            let scanOperationData = ScanOperationData(brokerId: brokerId, profileQueryId: profileQueryId, historyEvents: [lastHistoryEventToReturn])

            return BrokerProfileQueryData(dataBroker: .mock, profileQuery: .mock, scanOperationData: scanOperationData)
        } else {
            return nil
        }
    }

    func fetchAllBrokerProfileQueryData() -> [BrokerProfileQueryData] {
        wasFetchAllBrokerProfileQueryDataCalled = true
        return brokerProfileQueryDataToReturn
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) {
        lastPreferredRunDateOnScan = date
        lastProfileQueryIdOnScanUpdatePreferredRunDate = profileQueryId
        wasUpdatedPreferredRunDateForScanCalled = true
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) {
        lastPreferredRunDateOnOptOut = date
        wasUpdatedPreferredRunDateForOptOutCalled = true
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64) {
        wasUpdateLastRunDateForScanCalled = true
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) {
        wasUpdateLastRunDateForOptOutCalled = true
    }

    func updateRemovedDate(_ date: Date?, on extractedProfileId: Int64) {
        extractedProfileRemovedDate = date
        wasUpdateRemoveDateCalled = true
    }

    func add(_ historyEvent: HistoryEvent) {
        wasAddHistoryEventCalled = true
        eventsAdded.append(historyEvent)
    }

    func fetchLastEvent(brokerId: Int64, profileQueryId: Int64) -> HistoryEvent? {
        wasFetchLastHistoryEventCalled = true
        if let event = brokerProfileQueryDataToReturn.first?.events.last {
            return event
        }
        return lastHistoryEventToReturn
    }

    func fetchScanHistoryEvents(brokerId: Int64, profileQueryId: Int64) -> [HistoryEvent] {
        return [HistoryEvent]()
    }

    func fetchOptOutHistoryEvents(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) -> [HistoryEvent] {
        return historyEvents
    }

    func hasMatches() -> Bool {
        false
    }

    func fetchExtractedProfiles(for brokerId: Int64) -> [ExtractedProfile] {
        return extractedProfilesFromBroker
    }

    func fetchAttemptInformation(for extractedProfileId: Int64) -> AttemptInformation? {
        return attemptInformation
    }

    func addAttempt(extractedProfileId: Int64, attemptUUID: UUID, dataBroker: String, lastStageDate: Date, startTime: Date) {
    }

    func fetchChildBrokers(for parentBroker: String) -> [DataBroker] {
        lastParentBrokerWhereChildSitesWhereFetched = parentBroker
        return childBrokers
    }

    func clear() {
        wasSaveProfileCalled = false
        wasFetchProfileCalled = false
        wasSaveOptOutOperationCalled = false
        wasBrokerProfileQueryDataCalled = false
        wasFetchAllBrokerProfileQueryDataCalled = false
        wasUpdatedPreferredRunDateForScanCalled = false
        wasUpdatedPreferredRunDateForOptOutCalled = false
        wasUpdateLastRunDateForScanCalled = false
        wasUpdateLastRunDateForOptOutCalled = false
        wasUpdateRemoveDateCalled = false
        wasAddHistoryEventCalled = false
        wasFetchLastHistoryEventCalled = false
        eventsAdded.removeAll()
        lastHistoryEventToReturn = nil
        lastPreferredRunDateOnScan = nil
        lastPreferredRunDateOnOptOut = nil
        extractedProfileRemovedDate = nil
        extractedProfilesFromBroker.removeAll()
        childBrokers.removeAll()
        lastParentBrokerWhereChildSitesWhereFetched = nil
        lastProfileQueryIdOnScanUpdatePreferredRunDate = nil
        brokerProfileQueryDataToReturn.removeAll()
        profile = nil
        attemptInformation = nil
        historyEvents.removeAll()
    }
}

final class MockAppVersion: AppVersionNumberProvider {

    var versionNumber: String

    init(versionNumber: String) {
        self.versionNumber = versionNumber
    }
}

final class MockStageDurationCalculator: StageDurationCalculator {
    var attemptId: UUID = UUID()
    var stage: Stage?

    func durationSinceLastStage() -> Double {
        return 0.0
    }

    func durationSinceStartTime() -> Double {
        return 0.0
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

    func fireOptOutSubmitSuccess(tries: Int) {
    }

    func fireOptOutFillForm() {
    }

    func fireOptOutFailure(tries: Int) {
    }

    func fireScanSuccess(matchesFound: Int) {
    }

    func fireScanFailed() {
    }

    func fireScanError(error: any Error) {
    }

    func setStage(_ stage: DataBrokerProtection.Stage) {
        self.stage = stage
    }

    func setEmailPattern(_ emailPattern: String?) {
    }

    func setLastActionId(_ actionID: String) {
    }

    func clear() {
        self.stage = nil
    }
}

final class MockDataBrokerProtectionBackendServicePixels: DataBrokerProtectionBackendServicePixels {
    var fireEmptyAccessTokenWasCalled = false
    var fireGenerateEmailHTTPErrorWasCalled = false
    var statusCode: Int?

    func fireGenerateEmailHTTPError(statusCode: Int) {
        fireGenerateEmailHTTPErrorWasCalled = true
        self.statusCode = statusCode
    }

    func fireEmptyAccessToken(callSite: BackendServiceCallSite) {
        fireEmptyAccessTokenWasCalled = true
    }

    func reset() {
        fireEmptyAccessTokenWasCalled = false
        fireGenerateEmailHTTPErrorWasCalled = false
        statusCode = nil
    }
}
