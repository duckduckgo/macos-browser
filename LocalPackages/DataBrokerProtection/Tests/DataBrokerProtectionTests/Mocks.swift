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
            scanJobData: ScanJobData(brokerId: 1,
                                                 profileQueryId: 1,
                                                 preferredRunDate: preferredRunDate,
                                                 historyEvents: scanHistoryEvents,
                                                 lastRunDate: lastRunDate),
            optOutJobData: extractedProfile != nil ? [.mock(with: extractedProfile!)] : [OptOutJobData]()
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
    var errorStatusCodeToThrow: Int?

    func initializeWebView(showWebView: Bool) async {
        wasInitializeWebViewCalled = true
    }

    func load(url: URL) async throws {
        wasLoadCalledWithURL = url

        guard let statusCode = errorStatusCodeToThrow else { return }
        throw DataBrokerProtectionError.httpError(code: statusCode)
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

    func reset() {
        shouldSendNilAuthHeader = false
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
    var shouldSendNilWaitlistTimeStamp = false

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
        if shouldSendNilWaitlistTimeStamp {
            return nil
        }
        return 123
    }

    func reset() {
        shouldSendNilInviteCode = false
        shouldSendNilAccessToken = false
        wasInviteCodeSaveCalled = false
        wasAccessTokenSaveCalled = false
        shouldSendNilWaitlistTimeStamp = false
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
    var scanJobData = [ScanJobData]()
    var optOutJobData = [OptOutJobData]()
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
        scanJobData.removeAll()
        optOutJobData.removeAll()
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

    func fetchScan(brokerId: Int64, profileQueryId: Int64) throws -> ScanJobData? {
        scanJobData.first
    }

    func fetchAllScans() throws -> [ScanJobData] {
        return scanJobData
    }

    func save(brokerId: Int64, profileQueryId: Int64, extractedProfile: ExtractedProfile, lastRunDate: Date?, preferredRunDate: Date?) throws {
    }

    func save(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64, lastRunDate: Date?, preferredRunDate: Date?) throws {
    }

    func updatePreferredRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
    }

    func updateLastRunDate(_ date: Date?, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws {
    }

    func fetchOptOut(brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws -> OptOutJobData? {
        optOutJobData.first
    }

    func fetchOptOuts(brokerId: Int64, profileQueryId: Int64) throws -> [OptOutJobData] {
        return optOutJobData
    }

    func fetchAllOptOuts() throws -> [OptOutJobData] {
        return optOutJobData
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

    func saveOptOutJob(optOut: OptOutJobData, extractedProfile: ExtractedProfile) throws {
        wasSaveOptOutOperationCalled = true
    }

    func brokerProfileQueryData(for brokerId: Int64, and profileQueryId: Int64) -> BrokerProfileQueryData? {
        wasBrokerProfileQueryDataCalled = true

        if !brokerProfileQueryDataToReturn.isEmpty {
            return brokerProfileQueryDataToReturn.first
        }

        if let lastHistoryEventToReturn = self.lastHistoryEventToReturn {
            let scanJobData = ScanJobData(brokerId: brokerId, profileQueryId: profileQueryId, historyEvents: [lastHistoryEventToReturn])

            return BrokerProfileQueryData(dataBroker: .mock, profileQuery: .mock, scanJobData: scanJobData)
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
    var isImmediateOperation: Bool = false
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

final class MockRunnerProvider: JobRunnerProvider {
    func getJobRunner() -> any WebJobRunner {
        MockWebJobRunner()
    }
}

final class MockPixelHandler: EventMapping<DataBrokerProtectionPixels> {

    init() {
        super.init { event, _, _, _ in }
    }
}

extension ProfileQuery {

    static var mock: ProfileQuery {
        .init(id: 1, firstName: "First", lastName: "Last", city: "City", state: "State", birthYear: 1980)
    }

    static var mockWithoutId: ProfileQuery {
        .init(firstName: "First", lastName: "Last", city: "City", state: "State", birthYear: 1980)
    }
}

extension ScanJobData {

    static var mock: ScanJobData {
        .init(
            brokerId: 1,
            profileQueryId: 1,
            historyEvents: [HistoryEvent]()
        )
    }

    static func mockWith(historyEvents: [HistoryEvent]) -> ScanJobData {
        ScanJobData(brokerId: 1, profileQueryId: 1, historyEvents: historyEvents)
    }

    static func mock(withBrokerId brokerId: Int64) -> ScanJobData {
        .init(
            brokerId: brokerId,
            profileQueryId: 1,
            historyEvents: [HistoryEvent]()
        )
    }
}

extension OptOutJobData {
    static func mock(with extractedProfile: ExtractedProfile,
                     historyEvents: [HistoryEvent] = [HistoryEvent]()) -> OptOutJobData {
        .init(brokerId: 1, profileQueryId: 1, historyEvents: historyEvents, extractedProfile: extractedProfile)
    }
}

extension DataBroker {

    static func mock(withId id: Int64) -> DataBroker {
        DataBroker(
            id: id,
            name: "Test broker",
            url: "testbroker.com",
            steps: [Step](),
            version: "1.0",
            schedulingConfig: DataBrokerScheduleConfig(
                retryError: 0,
                confirmOptOutScan: 0,
                maintenanceScan: 0
            )
        )
    }
}

final class MockDataBrokerProtectionOperationQueueManager: DataBrokerProtectionQueueManager {
    var debugRunningStatusString: String { return "" }

    var startImmediateOperationsIfPermittedCompletionError: DataBrokerProtectionAgentErrorCollection?
    var startScheduledOperationsIfPermittedCompletionError: DataBrokerProtectionAgentErrorCollection?

    var startImmediateOperationsIfPermittedCalledCompletion: ((DataBrokerProtection.DataBrokerProtectionAgentErrorCollection?) -> Void)?
    var startScheduledOperationsIfPermittedCalledCompletion: ((DataBrokerProtection.DataBrokerProtectionAgentErrorCollection?) -> Void)?

    init(operationQueue: DataBrokerProtection.DataBrokerProtectionOperationQueue, operationsCreator: DataBrokerProtection.DataBrokerOperationsCreator, mismatchCalculator: DataBrokerProtection.MismatchCalculator, brokerUpdater: DataBrokerProtection.DataBrokerProtectionBrokerUpdater?, pixelHandler: Common.EventMapping<DataBrokerProtection.DataBrokerProtectionPixels>) {

    }

    func startImmediateOperationsIfPermitted(showWebView: Bool, operationDependencies: DataBrokerProtection.DataBrokerOperationDependencies, completion: ((DataBrokerProtection.DataBrokerProtectionAgentErrorCollection?) -> Void)?) {
        completion?(startImmediateOperationsIfPermittedCompletionError)
        startImmediateOperationsIfPermittedCalledCompletion?(startImmediateOperationsIfPermittedCompletionError)
    }

    func startScheduledOperationsIfPermitted(showWebView: Bool, operationDependencies: DataBrokerProtection.DataBrokerOperationDependencies, completion: ((DataBrokerProtection.DataBrokerProtectionAgentErrorCollection?) -> Void)?) {
        completion?(startScheduledOperationsIfPermittedCompletionError)
        startScheduledOperationsIfPermittedCalledCompletion?(startScheduledOperationsIfPermittedCompletionError)
    }

    func execute(_ command: DataBrokerProtection.DataBrokerProtectionQueueManagerDebugCommand) {
    }
}

final class MockUserNotificationService: DataBrokerProtectionUserNotificationService {

    var requestPermissionWasAsked = false
    var firstScanNotificationWasSent = false
    var firstRemovedNotificationWasSent = false
    var checkInNotificationWasScheduled = false
    var allInfoRemovedWasSent = false

    func requestNotificationPermission() {
        requestPermissionWasAsked = true
    }

    func sendFirstScanCompletedNotification() {
        firstScanNotificationWasSent = true
    }

    func sendFirstRemovedNotificationIfPossible() {
        firstRemovedNotificationWasSent = true
    }

    func sendAllInfoRemovedNotificationIfPossible() {
        allInfoRemovedWasSent = true
    }

    func scheduleCheckInNotificationIfPossible() {
        checkInNotificationWasScheduled = true
    }

    func reset() {
        requestPermissionWasAsked = false
        firstScanNotificationWasSent = false
        firstRemovedNotificationWasSent = false
        checkInNotificationWasScheduled = false
        allInfoRemovedWasSent = false
    }
}

final class MockDataBrokerProtectionBackgroundActivityScheduler: DataBrokerProtectionBackgroundActivityScheduler {

    var delegate: DataBrokerProtection.DataBrokerProtectionBackgroundActivitySchedulerDelegate?
    var lastTriggerTimestamp: Date?

    var startSchedulerCompletion: (() -> Void)?

    func startScheduler() {
        startSchedulerCompletion?()
    }

    func triggerDelegateCall() {
        delegate?.dataBrokerProtectionBackgroundActivitySchedulerDidTrigger(self, completion: nil)
    }
}

final class MockDataBrokerProtectionDataManager: DataBrokerProtectionDataManaging {

    var profileToReturn: DataBrokerProtectionProfile?
    var shouldReturnHasMatches = false

    var cache: DataBrokerProtection.InMemoryDataCache
    var delegate: DataBrokerProtection.DataBrokerProtectionDataManagerDelegate?

    init(pixelHandler: Common.EventMapping<DataBrokerProtection.DataBrokerProtectionPixels>, fakeBrokerFlag: DataBrokerProtection.DataBrokerDebugFlag) {
        cache = InMemoryDataCache()
    }

    func saveProfile(_ profile: DataBrokerProtection.DataBrokerProtectionProfile) async throws {
    }

    func fetchProfile() throws -> DataBrokerProtection.DataBrokerProtectionProfile? {
        return profileToReturn
    }

    func prepareProfileCache() throws {
    }

    func fetchBrokerProfileQueryData(ignoresCache: Bool) throws -> [DataBrokerProtection.BrokerProfileQueryData] {
        return []
    }

    func prepareBrokerProfileQueryDataCache() throws {
    }

    func hasMatches() throws -> Bool {
        return shouldReturnHasMatches
    }

    func profileQueriesCount() throws -> Int {
        return 0
    }
}

final class MockIPCServer: DataBrokerProtectionIPCServer {

    var serverDelegate: DataBrokerProtection.DataBrokerProtectionAppToAgentInterface?

    init(machServiceName: String) {
    }

    func activate() {
    }

    func register() {
    }

    func profileSaved(xpcMessageReceivedCompletion: @escaping (Error?) -> Void) {
        serverDelegate?.profileSaved()
    }

    func appLaunched(xpcMessageReceivedCompletion: @escaping (Error?) -> Void) {
        serverDelegate?.appLaunched()
    }

    func openBrowser(domain: String) {
        serverDelegate?.openBrowser(domain: domain)
    }

    func startImmediateOperations(showWebView: Bool) {
        serverDelegate?.startImmediateOperations(showWebView: showWebView)
    }

    func startScheduledOperations(showWebView: Bool) {
        serverDelegate?.startScheduledOperations(showWebView: showWebView)
    }

    func runAllOptOuts(showWebView: Bool) {
        serverDelegate?.runAllOptOuts(showWebView: showWebView)
    }

    func getDebugMetadata(completion: @escaping (DataBrokerProtection.DBPBackgroundAgentMetadata?) -> Void) {
        serverDelegate?.profileSaved()
    }
}

final class MockDataBrokerProtectionOperationQueue: DataBrokerProtectionOperationQueue {
    var maxConcurrentOperationCount = 1

    var operations: [Operation] = []
    var operationCount: Int {
        operations.count
    }

    private(set) var didCallCancelCount = 0
    private(set) var didCallAddCount = 0
    private(set) var didCallAddBarrierBlockCount = 0

    private var barrierBlock: (@Sendable () -> Void)?

    func cancelAllOperations() {
        didCallCancelCount += 1
        self.operations.forEach { $0.cancel() }
    }

    func addOperation(_ op: Operation) {
        didCallAddCount += 1
        self.operations.append(op)
    }

    func addBarrierBlock(_ barrier: @escaping @Sendable () -> Void) {
        didCallAddBarrierBlockCount += 1
        self.barrierBlock = barrier
    }

    func completeAllOperations() {
        operations.forEach { $0.start() }
        operations.removeAll()
        barrierBlock?()
    }

    func completeOperationsUpTo(index: Int) {
        guard index < operationCount else { return }

        (0..<index).forEach {
            operations[$0].start()
        }

        (0..<index).forEach {
            operations.remove(at: $0)
        }
    }
}

final class MockDataBrokerOperation: DataBrokerOperation {

    private var shouldError = false
    private var _isExecuting = false
    private var _isFinished = false
    private var _isCancelled = false
    private var operationsManager: OperationsManager!

    convenience init(id: Int64,
                     operationType: OperationType,
                     errorDelegate: DataBrokerOperationErrorDelegate,
                     shouldError: Bool = false) {

        self.init(dataBrokerID: id,
                  operationType: operationType,
                  showWebView: false,
                  errorDelegate: errorDelegate,
                  operationDependencies: DefaultDataBrokerOperationDependencies.mock)

        self.shouldError = shouldError
    }

    override func main() {
        if shouldError {
            errorDelegate?.dataBrokerOperationDidError(DataBrokerProtectionError.noActionFound, withBrokerName: nil)
        }

        finish()
    }

    override func cancel() {
        self._isCancelled = true
    }

    override var isCancelled: Bool {
        _isCancelled
    }

    override var isAsynchronous: Bool {
        return true
    }

    override var isExecuting: Bool {
        return _isExecuting
    }

    override var isFinished: Bool {
        return _isFinished
    }

    private func finish() {
        willChangeValue(forKey: #keyPath(isExecuting))
        willChangeValue(forKey: #keyPath(isFinished))

        _isExecuting = false
        _isFinished = true

        didChangeValue(forKey: #keyPath(isExecuting))
        didChangeValue(forKey: #keyPath(isFinished))
    }
}

final class MockDataBrokerOperationErrorDelegate: DataBrokerOperationErrorDelegate {

    var operationErrors: [Error] = []

    func dataBrokerOperationDidError(_ error: any Error, withBrokerName brokerName: String?) {
        operationErrors.append(error)
    }
}

extension DefaultDataBrokerOperationDependencies {
    static var mock: DefaultDataBrokerOperationDependencies {
        DefaultDataBrokerOperationDependencies(database: MockDatabase(),
                                               config: DataBrokerExecutionConfig(),
                                               runnerProvider: MockRunnerProvider(),
                                               notificationCenter: .default,
                                               pixelHandler: MockPixelHandler(),
                                               userNotificationService: MockUserNotificationService())
    }
}

final class MockDataBrokerOperationsCreator: DataBrokerOperationsCreator {

    var operationCollections: [DataBrokerOperation] = []
    var shouldError = false
    var priorityDate: Date?
    var createdType: OperationType = .scan

    init(operationCollections: [DataBrokerOperation] = []) {
        self.operationCollections = operationCollections
    }

    func operations(forOperationType operationType: OperationType,
                    withPriorityDate priorityDate: Date?,
                    showWebView: Bool,
                    errorDelegate: DataBrokerOperationErrorDelegate,
                    operationDependencies: DataBrokerOperationDependencies) throws -> [DataBrokerOperation] {
        guard !shouldError else { throw DataBrokerProtectionError.unknown("")}
        self.createdType = operationType
        self.priorityDate = priorityDate
        return operationCollections
    }
}

final class MockMismatchCalculator: MismatchCalculator {

    private(set) var didCallCalculateMismatches = false

    init(database: any DataBrokerProtectionRepository, pixelHandler: Common.EventMapping<DataBrokerProtectionPixels>) { }

    func calculateMismatches() {
        didCallCalculateMismatches = true
    }
}

final class MockDataBrokerProtectionBrokerUpdater: DataBrokerProtectionBrokerUpdater {

    private(set) var didCallUpdateBrokers = false
    private(set) var didCallCheckForUpdates = false

    static func provideForDebug() -> DefaultDataBrokerProtectionBrokerUpdater? {
        nil
    }

    func updateBrokers() {
        didCallUpdateBrokers = true
    }

    func checkForUpdatesInBrokerJSONFiles() {
        didCallCheckForUpdates = true
    }
}

final class MockAuthenticationManager: DataBrokerProtectionAuthenticationManaging {
    var isUserAuthenticatedValue = false
    var accessTokenValue: String? = "fake token"
    var shouldAskForInviteCodeValue = false
    var redeemCodeCalled = false
    var authHeaderValue: String? = "fake auth header"
    var hasValidEntitlementValue = false
    var shouldThrowEntitlementError = false

    var isUserAuthenticated: Bool { isUserAuthenticatedValue }

    var accessToken: String? { accessTokenValue }

    func hasValidEntitlement() async throws -> Bool {
        if shouldThrowEntitlementError {
            throw NSError(domain: "duck.com", code: 0, userInfo: [NSLocalizedDescriptionKey: "Error"])
        }
        return hasValidEntitlementValue
    }

    func shouldAskForInviteCode() -> Bool { shouldAskForInviteCodeValue }

    func redeem(inviteCode: String) async throws {
        redeemCodeCalled = true
    }

    func getAuthHeader() -> String? { authHeaderValue }

    func reset() {
        isUserAuthenticatedValue = false
        accessTokenValue = "fake token"
        shouldAskForInviteCodeValue = false
        redeemCodeCalled = false
        authHeaderValue = "fake auth header"
        hasValidEntitlementValue = false
        shouldThrowEntitlementError = false
    }
}

final class MockAgentStopper: DataBrokerProtectionAgentStopper {
    var validateRunPrerequisitesCompletion: (() -> Void)?
    var monitorEntitlementCompletion: (() -> Void)?

    func validateRunPrerequisitesAndStopAgentIfNecessary() async {
        validateRunPrerequisitesCompletion?()
    }

    func monitorEntitlementAndStopAgentIfEntitlementIsInvalid(interval: TimeInterval) {
        monitorEntitlementCompletion?()
    }
}

final class MockDataProtectionStopAction: DataProtectionStopAction {
    var wasStopCalled = false
    var stopAgentCompletion: (() -> Void)?

    func stopAgent() {
        wasStopCalled = true
        stopAgentCompletion?()
    }

    func reset() {
        wasStopCalled = false
    }
}

public final class MockDBPKeychainService: KeychainService {

    public enum Mode {
        case nothingFound
        case migratedDataFound
        case legacyDataFound
        case readError
        case updateError

        var statusCode: Int32? {
            switch self {
            case .readError:
                return -25295
            case .updateError:
                return -25299
            default:
                return nil
            }
        }
    }

    public var latestItemMatchingQuery: [String: Any] = [:]
    public var latestUpdateQuery: [String: Any] = [:]
    public var latestAddQuery: [String: Any] = [:]
    public var latestUpdateAttributes: [String: Any] = [:]
    public var addCallCount = 0
    public var itemMatchingCallCount = 0
    public var updateCallCount = 0

    public var mode: Mode = .nothingFound

    public init() {}

    public func itemMatching(_ query: [String: Any], _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        itemMatchingCallCount += 1
        latestItemMatchingQuery = query

        func setResult() {
            let originalString = "Mock Keychain data!"
            let data = originalString.data(using: .utf8)!
            let encodedString = data.base64EncodedString()
            let mockResult = encodedString.data(using: .utf8)! as CFData

            if let result = result {
                result.pointee = mockResult
            }
        }

        switch mode {
        case .nothingFound:
            return errSecItemNotFound
        case .migratedDataFound:
            setResult()
            return errSecSuccess
        case .legacyDataFound, .updateError:
            if itemMatchingCallCount == 2 {
                setResult()
                return errSecSuccess
            } else {
                return errSecItemNotFound
            }
        case .readError:
            return errSecInvalidKeychain
        }
    }

    public func add(_ query: [String: Any], _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        latestAddQuery = query
        addCallCount += 1
        return errSecSuccess
    }

    public func update(_ query: [String: Any], _ attributesToUpdate: [String: Any]) -> OSStatus {
        guard mode != .updateError else { return errSecDuplicateItem }
        updateCallCount += 1
        latestUpdateQuery = query
        latestUpdateAttributes = attributesToUpdate
        return errSecSuccess
    }
}

struct MockGroupNameProvider: GroupNameProviding {
    var appGroupName: String {
        return "mockGroup"
    }
}

extension SecureStorageError: Equatable {
    public static func == (lhs: SecureStorageError, rhs: SecureStorageError) -> Bool {
        switch (lhs, rhs) {
        case (.initFailed(let cause1), .initFailed(let cause2)):
            return cause1.localizedDescription == cause2.localizedDescription
        case (.authError(let cause1), .authError(let cause2)):
            return cause1.localizedDescription == cause2.localizedDescription
        case (.failedToOpenDatabase(let cause1), .failedToOpenDatabase(let cause2)):
            return cause1.localizedDescription == cause2.localizedDescription
        case (.databaseError(let cause1), .databaseError(let cause2)):
            return cause1.localizedDescription == cause2.localizedDescription
        case (.keystoreError(let status1), .keystoreError(let status2)):
            return status1 == status2
        case (.secError(let status1), .secError(let status2)):
            return status1 == status2
        case (.keystoreReadError(let status1), .keystoreReadError(let status2)):
            return status1 == status2
        case (.keystoreUpdateError(let status1), .keystoreUpdateError(let status2)):
            return status1 == status2
        case (.authRequired, .authRequired), (.invalidPassword, .invalidPassword),
            (.noL1Key, .noL1Key), (.noL2Key, .noL2Key), (.duplicateRecord, .duplicateRecord),
            (.generalCryptoError, .generalCryptoError), (.encodingFailed, .encodingFailed):
            return true
        default:
            return false
        }
    }
}

final class MockDataBrokerProtectionStatsPixelsRepository: DataBrokerProtectionStatsPixelsRepository {
    var wasMarkStatsWeeklyPixelDateCalled: Bool = false
    var wasMarkStatsMonthlyPixelDateCalled: Bool = false
    var latestStatsWeeklyPixelDate: Date?
    var latestStatsMonthlyPixelDate: Date?

    func markStatsWeeklyPixelDate() {
        wasMarkStatsWeeklyPixelDateCalled = true
    }

    func markStatsMonthlyPixelDate() {
        wasMarkStatsMonthlyPixelDateCalled = true
    }

    func getLatestStatsWeeklyPixelDate() -> Date? {
        return latestStatsWeeklyPixelDate
    }

    func getLatestStatsMonthlyPixelDate() -> Date? {
        return latestStatsMonthlyPixelDate
    }

    func clear() {
        wasMarkStatsWeeklyPixelDateCalled = false
        wasMarkStatsMonthlyPixelDateCalled = false
        latestStatsWeeklyPixelDate = nil
        latestStatsMonthlyPixelDate = nil
    }
}

final class MockSleepObserver: SleepObserver {
    func totalSleepTime() -> TimeInterval {
        1
    }
}

final class MockActionsHandler: ActionsHandler {

    var didCallNextAction = false

    init() {
        super.init(step: Step(type: .scan, actions: []))
    }

    override func nextAction() -> (any Action)? {
        didCallNextAction = true
        return nil
    }
}

private extension String {
    static func random(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
}

private extension Int {
    static func randomBirthdate() -> Int {
        Int.random(in: 1960...2000)
    }
}

extension Int64 {
    static func randomValues(ofLength length: Int = 20, start: Int64 = 1001, end: Int64 = 2000) -> [Int64] {
        [0..<length].map { _ in
            Int64.random(in: start..<end)
        }
    }
}

private extension Data {
    static func randomStringData(length: Int) -> Data {
        String.random(length: length).data(using: .utf8)!
    }

    static func randomBirthdateData() -> Data {
        String(Int.randomBirthdate()).data(using: .utf8)!
    }

    static func randomEventData(length: Int) -> Data {
            return .randomStringData(length: length)
        }
}

extension Date {
    static func random() -> Date {
        let currentTime = Date().timeIntervalSince1970
        let randomTimeInterval = TimeInterval.random(in: 0..<currentTime)
        return Date(timeIntervalSince1970: randomTimeInterval)
    }
}

extension ProfileQueryDB {
    static func random(withProfileIds profileIds: [Int64]) -> [ProfileQueryDB] {
        profileIds.map {
            ProfileQueryDB(id: nil, profileId: $0,
                                         first: .randomStringData(length: 4),
                                         last: .randomStringData(length: 4),
                                         middle: nil,
                                         suffix: nil,
                                         city: .randomStringData(length: 4),
                                         state: .randomStringData(length: 4), street: .randomStringData(length: 4),
                                         zipCode: nil,
                                         phone: nil,
                                         birthYear: Data.randomBirthdateData(),
                                         deprecated: Bool.random())
        }
    }
}

extension BrokerDB {
    static func random(count: Int) -> [BrokerDB] {
        [0..<count].map {
            BrokerDB(id: nil, name: .random(length: 4),
                     json: try! JSONSerialization.data(withJSONObject: [:], options: []),
                     version: "\($0).\($0).\($0)",
                     url: "www.testbroker.com")
        }
    }
}

extension ScanHistoryEventDB {
    static func random(withBrokerIds brokerIds: [Int64], profileQueryIds: [Int64]) -> [ScanHistoryEventDB] {
        brokerIds.flatMap { brokerId in
            profileQueryIds.map { profileQueryId in
                ScanHistoryEventDB(
                    brokerId: brokerId,
                    profileQueryId: profileQueryId,
                    event: .randomEventData(length: 8),
                    timestamp: .random()
                )
            }
        }
    }
}

extension OptOutHistoryEventDB {
    static func random(withBrokerIds brokerIds: [Int64], profileQueryIds: [Int64], extractedProfileIds: [Int64]) -> [OptOutHistoryEventDB] {
        brokerIds.flatMap { brokerId in
            profileQueryIds.flatMap { profileQueryId in
                extractedProfileIds.map { extractedProfileId in
                    OptOutHistoryEventDB(
                        brokerId: brokerId,
                        profileQueryId: profileQueryId,
                        extractedProfileId: extractedProfileId,
                        event: .randomEventData(length: 8),
                        timestamp: .random()
                    )
                }
            }
        }
    }
}

extension ExtractedProfileDB {
    static func random(withBrokerIds brokerIds: [Int64], profileQueryIds: [Int64]) -> [ExtractedProfileDB] {
        brokerIds.flatMap { brokerId in
            profileQueryIds.map { profileQueryId in
                ExtractedProfileDB(
                    id: nil,
                    brokerId: brokerId,
                    profileQueryId: profileQueryId,
                    profile: .randomEventData(length: 50),
                    removedDate: Bool.random() ? .random() : nil
                )
            }
        }
    }
}

struct MockMigrationsProvider: DataBrokerProtectionDatabaseMigrationsProvider {
    static var didCallV2Migrations = false
    static var didCallV3Migrations = false

    static var v2Migrations: (inout GRDB.DatabaseMigrator) throws -> Void {
        didCallV2Migrations = true
        return { _ in }
    }

    static var v3Migrations: (inout GRDB.DatabaseMigrator) throws -> Void {
        didCallV3Migrations = true
        return { _ in }
    }
}
