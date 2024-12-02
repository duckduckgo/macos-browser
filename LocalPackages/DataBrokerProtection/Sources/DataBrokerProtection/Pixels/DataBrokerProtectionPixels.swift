//
//  DataBrokerProtectionPixels.swift
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
import Common
import BrowserServicesKit
import Configuration
import PixelKit

enum ErrorCategory: Equatable {
    case networkError
    case validationError
    case clientError(httpCode: Int)
    case serverError(httpCode: Int)
    case databaseError(domain: String, code: Int)
    case unclassified

    var toString: String {
        switch self {
        case .networkError: return "network-error"
        case .validationError: return "validation-error"
        case .unclassified: return "unclassified"
        case .clientError(let httpCode): return "client-error-\(httpCode)"
        case .serverError(let httpCode): return "server-error-\(httpCode)"
        case .databaseError(let domain, let code): return "database-error-\(domain)-\(code)"
        }
    }
}

public enum DataBrokerProtectionPixels {
    struct Consts {
        static let dataBrokerParamKey = "data_broker"
        static let dataBrokerVersionKey = "broker_version"
        static let appVersionParamKey = "app_version"
        static let attemptIdParamKey = "attempt_id"
        static let durationParamKey = "duration"
        static let bundleIDParamKey = "bundle_id"
        static let stageKey = "stage"
        static let matchesFoundKey = "num_found"
        static let triesKey = "tries"
        static let errorCategoryKey = "error_category"
        static let errorDetailsKey = "error_details"
        static let errorDomainKey = "error_domain"
        static let pattern = "pattern"
        static let isParent = "is_parent"
        static let actionIDKey = "action_id"
        static let hadNewMatch = "had_new_match"
        static let hadReAppereance = "had_re-appearance"
        static let scanCoverage = "scan_coverage"
        static let removals = "removals"
        static let environmentKey = "environment"
        static let wasOnWaitlist = "was_on_waitlist"
        static let httpCode = "http_code"
        static let backendServiceCallSite = "backend_service_callsite"
        static let isImmediateOperation = "is_manual_scan"
        static let durationInMs = "duration_in_ms"
        static let profileQueries = "profile_queries"
        static let hasError = "has_error"
        static let brokerURL = "broker_url"
        static let sleepDuration = "sleep_duration"
        static let numberOfRecordsFound = "num_found"
        static let numberOfOptOutsInProgress = "num_inprogress"
        static let numberOfSucessfulOptOuts = "num_optoutsuccess"
        static let numberOfOptOutsFailure = "num_optoutfailure"
        static let durationOfFirstOptOut = "duration_firstoptout"
        static let numberOfNewRecordsFound = "num_new_found"
        static let numberOfReappereances = "num_reappeared"
        static let optOutSubmitSuccessRate = "optout_submit_success_rate"
        static let childParentRecordDifference = "child-parent-record-difference"
        static let calculatedOrphanedRecords = "calculated-orphaned-records"
    }

    case error(error: DataBrokerProtectionError, dataBroker: String)
    case generalError(error: Error, functionOccurredIn: String)
    case secureVaultInitError(error: Error)
    case secureVaultKeyStoreReadError(error: Error)
    case secureVaultKeyStoreUpdateError(error: Error)
    case secureVaultError(error: Error)
    case parentChildMatches(parent: String, child: String, value: Int)

    // Stage Pixels
    case optOutStart(dataBroker: String, attemptId: UUID)
    case optOutEmailGenerate(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutCaptchaParse(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutCaptchaSend(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutCaptchaSolve(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutSubmit(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutEmailReceive(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutEmailConfirm(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutValidate(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutFinish(dataBroker: String, attemptId: UUID, duration: Double)
    case optOutFillForm(dataBroker: String, attemptId: UUID, duration: Double)

    // Process Pixels
    case optOutSubmitSuccess(dataBroker: String, attemptId: UUID, duration: Double, tries: Int, emailPattern: String?)
    case optOutSuccess(dataBroker: String, attemptId: UUID, duration: Double, brokerType: DataBrokerHierarchy)
    case optOutFailure(dataBroker: String, dataBrokerVersion: String, attemptId: UUID, duration: Double, stage: String, tries: Int, emailPattern: String?, actionID: String?)

    // Backgrond Agent events
    case backgroundAgentStarted
    case backgroundAgentStartedStoppingDueToAnotherInstanceRunning

    // IPC server events
    case ipcServerProfileSavedCalledByApp
    case ipcServerProfileSavedReceivedByAgent
    case ipcServerProfileSavedXPCError(error: Error?)
    case ipcServerImmediateScansInterrupted
    case ipcServerImmediateScansFinishedWithoutError
    case ipcServerImmediateScansFinishedWithError(error: Error?)

    case ipcServerAppLaunchedCalledByApp
    case ipcServerAppLaunchedReceivedByAgent
    case ipcServerAppLaunchedXPCError(error: Error?)
    case ipcServerAppLaunchedScheduledScansBlocked
    case ipcServerAppLaunchedScheduledScansInterrupted
    case ipcServerAppLaunchedScheduledScansFinishedWithoutError
    case ipcServerAppLaunchedScheduledScansFinishedWithError(error: Error?)

    // DataBrokerProtection User Notifications
    case dataBrokerProtectionNotificationSentFirstScanComplete
    case dataBrokerProtectionNotificationOpenedFirstScanComplete
    case dataBrokerProtectionNotificationSentFirstRemoval
    case dataBrokerProtectionNotificationOpenedFirstRemoval
    case dataBrokerProtectionNotificationScheduled2WeeksCheckIn
    case dataBrokerProtectionNotificationOpened2WeeksCheckIn
    case dataBrokerProtectionNotificationSentAllRecordsRemoved
    case dataBrokerProtectionNotificationOpenedAllRecordsRemoved

    // Scan/Search pixels
    case scanSuccess(dataBroker: String, matchesFound: Int, duration: Double, tries: Int, isImmediateOperation: Bool)
    case scanFailed(dataBroker: String, dataBrokerVersion: String, duration: Double, tries: Int, isImmediateOperation: Bool)
    case scanError(dataBroker: String, dataBrokerVersion: String, duration: Double, category: String, details: String, isImmediateOperation: Bool)

    // KPIs - engagement
    case dailyActiveUser
    case weeklyActiveUser
    case monthlyActiveUser

    // KPIs - events
    case weeklyReportScanning(hadNewMatch: Bool, hadReAppereance: Bool, scanCoverage: String)
    case weeklyReportRemovals(removals: Int)
    case scanningEventNewMatch
    case scanningEventReAppearance

    // Additional opt out metrics
    case optOutJobAt7DaysConfirmed(dataBroker: String)
    case optOutJobAt7DaysUnconfirmed(dataBroker: String)
    case optOutJobAt14DaysConfirmed(dataBroker: String)
    case optOutJobAt14DaysUnconfirmed(dataBroker: String)
    case optOutJobAt21DaysConfirmed(dataBroker: String)
    case optOutJobAt21DaysUnconfirmed(dataBroker: String)

    // Web UI - loading errors
    case webUILoadingStarted(environment: String)
    case webUILoadingFailed(errorCategory: String)
    case webUILoadingSuccess(environment: String)

    // Backend service errors
    case generateEmailHTTPErrorDaily(statusCode: Int, environment: String, wasOnWaitlist: Bool)
    case emptyAccessTokenDaily(environment: String, wasOnWaitlist: Bool, callSite: BackendServiceCallSite)

    // Home View
    case homeViewShowNoPermissionError
    case homeViewShowWebUI
    case homeViewShowBadPathError
    case homeViewCTAMoveApplicationClicked
    case homeViewCTAGrantPermissionClicked

    // Initial scans pixels
    // https://app.asana.com/0/1204006570077678/1206981742767458/f
    case initialScanTotalDuration(duration: Double, profileQueries: Int)
    case initialScanSiteLoadDuration(duration: Double, hasError: Bool, brokerURL: String, sleepDuration: Double)
    case initialScanPostLoadingDuration(duration: Double, hasError: Bool, brokerURL: String, sleepDuration: Double)
    case initialScanPreStartDuration(duration: Double)

    // Entitlements
    case entitlementCheckValid
    case entitlementCheckInvalid
    case entitlementCheckError

    // Configuration
    case invalidPayload(Configuration)
    case errorLoadingCachedConfig(Error)
    case failedToParsePrivacyConfig(Error)

    // Measure success/failure rate of Personal Information Removal Pixels
    // https://app.asana.com/0/1204006570077678/1206889724879222/f
    case globalMetricsWeeklyStats(profilesFound: Int, optOutsInProgress: Int, successfulOptOuts: Int, failedOptOuts: Int, durationOfFirstOptOut: Int, numberOfNewRecordsFound: Int)
    case globalMetricsMonthlyStats(profilesFound: Int, optOutsInProgress: Int, successfulOptOuts: Int, failedOptOuts: Int, durationOfFirstOptOut: Int, numberOfNewRecordsFound: Int)
    case dataBrokerMetricsWeeklyStats(dataBrokerURL: String, profilesFound: Int, optOutsInProgress: Int, successfulOptOuts: Int, failedOptOuts: Int, durationOfFirstOptOut: Int, numberOfNewRecordsFound: Int, numberOfReappereances: Int)
    case dataBrokerMetricsMonthlyStats(dataBrokerURL: String, profilesFound: Int, optOutsInProgress: Int, successfulOptOuts: Int, failedOptOuts: Int, durationOfFirstOptOut: Int, numberOfNewRecordsFound: Int, numberOfReappereances: Int)

    // Custom stats
    case customDataBrokerStatsOptoutSubmit(dataBrokerName: String, optOutSubmitSuccessRate: Double)
    case customGlobalStatsOptoutSubmit(optOutSubmitSuccessRate: Double)
    case weeklyChildBrokerOrphanedOptOuts(dataBrokerName: String, childParentRecordDifference: Int, calculatedOrphanedRecords: Int)
}

extension DataBrokerProtectionPixels: PixelKitEvent {
    public var name: String {
        switch self {
        case .parentChildMatches: return "m_mac_dbp_macos_parent-child-broker-matches"
            // SLO and SLI Pixels: https://app.asana.com/0/1203581873609357/1205337273100857/f
            // Stage Pixels
        case .optOutStart: return "m_mac_dbp_macos_optout_stage_start"
        case .optOutEmailGenerate: return "m_mac_dbp_macos_optout_stage_email-generate"
        case .optOutCaptchaParse: return "m_mac_dbp_macos_optout_stage_captcha-parse"
        case .optOutCaptchaSend: return "m_mac_dbp_macos_optout_stage_captcha-send"
        case .optOutCaptchaSolve: return "m_mac_dbp_macos_optout_stage_captcha-solve"
        case .optOutSubmit: return "m_mac_dbp_macos_optout_stage_submit"
        case .optOutEmailReceive: return "m_mac_dbp_macos_optout_stage_email-receive"
        case .optOutEmailConfirm: return "m_mac_dbp_macos_optout_stage_email-confirm"
        case .optOutValidate: return "m_mac_dbp_macos_optout_stage_validate"
        case .optOutFinish: return "m_mac_dbp_macos_optout_stage_finish"
        case .optOutFillForm: return "m_mac_dbp_macos_optout_stage_fill-form"

            // Process Pixels
        case .optOutSubmitSuccess: return "m_mac_dbp_macos_optout_process_submit-success"
        case .optOutSuccess: return "m_mac_dbp_macos_optout_process_success"
        case .optOutFailure: return "m_mac_dbp_macos_optout_process_failure"

            // Scan/Search pixels: https://app.asana.com/0/1203581873609357/1205337273100855/f
        case .scanSuccess: return "m_mac_dbp_macos_search_stage_main_status_success"
        case .scanFailed: return "m_mac_dbp_macos_search_stage_main_status_failure"
        case .scanError: return "m_mac_dbp_macos_search_stage_main_status_error"

            // Debug Pixels
        case .error: return "m_mac_data_broker_error"
        case .generalError: return "m_mac_data_broker_error"
        case .secureVaultInitError: return "m_mac_dbp_secure_vault_init_error"
        case .secureVaultKeyStoreReadError: return "m_mac_dbp_secure_vault_keystore_read_error"
        case .secureVaultKeyStoreUpdateError: return "m_mac_dbp_secure_vault_keystore_update_error"
        case .secureVaultError: return "m_mac_dbp_secure_vault_error"

        case .backgroundAgentStarted: return "m_mac_dbp_background-agent_started"
        case .backgroundAgentStartedStoppingDueToAnotherInstanceRunning: return "m_mac_dbp_background-agent_started_stopping-due-to-another-instance-running"

            // IPC Server Pixels
        case .ipcServerProfileSavedCalledByApp: return "m_mac_dbp_ipc-server_profile-saved_called-by-app"
        case .ipcServerProfileSavedReceivedByAgent: return "m_mac_dbp_ipc-server_profile-saved_received-by-agent"
        case .ipcServerProfileSavedXPCError: return "m_mac_dbp_ipc-server_profile-saved_xpc-error"
        case .ipcServerImmediateScansInterrupted: return "m_mac_dbp_ipc-server_immediate-scans_interrupted"
        case .ipcServerImmediateScansFinishedWithoutError: return "m_mac_dbp_ipc-server_immediate-scans_finished_without-error"
        case .ipcServerImmediateScansFinishedWithError: return "m_mac_dbp_ipc-server_immediate-scans_finished_with-error"

        case .ipcServerAppLaunchedCalledByApp: return "m_mac_dbp_ipc-server_app-launched_called-by-app"
        case .ipcServerAppLaunchedReceivedByAgent: return "m_mac_dbp_ipc-server_app-launched_received-by-agent"
        case .ipcServerAppLaunchedXPCError: return "m_mac_dbp_ipc-server_app-launched_xpc-error"
        case .ipcServerAppLaunchedScheduledScansBlocked: return "m_mac_dbp_ipc-server_app-launched_scheduled-scans_blocked"
        case .ipcServerAppLaunchedScheduledScansInterrupted: return "m_mac_dbp_ipc-server_app-launched_scheduled-scans_interrupted"
        case .ipcServerAppLaunchedScheduledScansFinishedWithoutError: return "m_mac_dbp_ipc-server_app-launched_scheduled-scans_finished_without-error"
        case .ipcServerAppLaunchedScheduledScansFinishedWithError: return "m_mac_dbp_ipc-server_app-launched_scheduled-scans_finished_with-error"

            // User Notifications
        case .dataBrokerProtectionNotificationSentFirstScanComplete:
            return "m_mac_dbp_notification_sent_first_scan_complete"
        case .dataBrokerProtectionNotificationOpenedFirstScanComplete:
            return "m_mac_dbp_notification_opened_first_scan_complete"
        case .dataBrokerProtectionNotificationSentFirstRemoval:
            return "m_mac_dbp_notification_sent_first_removal"
        case .dataBrokerProtectionNotificationOpenedFirstRemoval:
            return "m_mac_dbp_notification_opened_first_removal"
        case .dataBrokerProtectionNotificationScheduled2WeeksCheckIn:
            return "m_mac_dbp_notification_scheduled_2_weeks_check_in"
        case .dataBrokerProtectionNotificationOpened2WeeksCheckIn:
            return "m_mac_dbp_notification_opened_2_weeks_check_in"
        case .dataBrokerProtectionNotificationSentAllRecordsRemoved:
            return "m_mac_dbp_notification_sent_all_records_removed"
        case .dataBrokerProtectionNotificationOpenedAllRecordsRemoved:
            return "m_mac_dbp_notification_opened_all_records_removed"

            // KPIs - engagement
        case .dailyActiveUser: return "m_mac_dbp_engagement_dau"
        case .weeklyActiveUser: return "m_mac_dbp_engagement_wau"
        case .monthlyActiveUser: return "m_mac_dbp_engagement_mau"

        case .weeklyReportScanning: return "m_mac_dbp_event_weekly-report_scanning"
        case .weeklyReportRemovals: return "m_mac_dbp_event_weekly-report_removals"
        case .scanningEventNewMatch: return "m_mac_dbp_event_scanning-events_new-match"
        case .scanningEventReAppearance: return "m_mac_dbp_event_scanning-events_re-appearance"

        case .webUILoadingStarted: return "m_mac_dbp_web_ui_loading_started"
        case .webUILoadingSuccess: return "m_mac_dbp_web_ui_loading_success"
        case .webUILoadingFailed: return "m_mac_dbp_web_ui_loading_failed"

            // Additional opt out metrics
        case .optOutJobAt7DaysConfirmed: return "m_mac_dbp_optoutjob_at-7-days_confirmed"
        case .optOutJobAt7DaysUnconfirmed: return "m_mac_dbp_optoutjob_at-7-days_unconfirmed"
        case .optOutJobAt14DaysConfirmed: return "m_mac_dbp_optoutjob_at-14-days_confirmed"
        case .optOutJobAt14DaysUnconfirmed: return "m_mac_dbp_optoutjob_at-14-days_unconfirmed"
        case .optOutJobAt21DaysConfirmed: return "m_mac_dbp_optoutjob_at-21-days_confirmed"
        case .optOutJobAt21DaysUnconfirmed: return "m_mac_dbp_optoutjob_at-21-days_unconfirmed"

            // Backend service errors
        case .generateEmailHTTPErrorDaily: return "m_mac_dbp_service_email-generate-http-error"
        case .emptyAccessTokenDaily: return "m_mac_dbp_service_empty-auth-token"

            // Home View
        case .homeViewShowNoPermissionError: return "m_mac_dbp_home_view_show-no-permission-error"
        case .homeViewShowWebUI: return "m_mac_dbp_home_view_show-web-ui"
        case .homeViewShowBadPathError: return "m_mac_dbp_home_view_show-bad-path-error"
        case .homeViewCTAMoveApplicationClicked: return "m_mac_dbp_home_view-cta-move-application-clicked"
        case .homeViewCTAGrantPermissionClicked: return "m_mac_dbp_home_view-cta-grant-permission-clicked"

            // Initial scans pixels
        case .initialScanTotalDuration: return "m_mac_dbp_initial_scan_duration"
        case .initialScanSiteLoadDuration: return "m_mac_dbp_scan_broker_site_loaded"
        case .initialScanPostLoadingDuration: return "m_mac_dbp_initial_scan_broker_post_loading"
        case .initialScanPreStartDuration: return "m_mac_dbp_initial_scan_pre_start_duration"

            // Entitlements
        case .entitlementCheckValid: return "m_mac_dbp_macos_entitlement_valid"
        case .entitlementCheckInvalid: return "m_mac_dbp_macos_entitlement_invalid"
        case .entitlementCheckError: return "m_mac_dbp_macos_entitlement_error"

        case .globalMetricsWeeklyStats: return "m_mac_dbp_weekly_stats"
        case .globalMetricsMonthlyStats: return "m_mac_dbp_monthly_stats"
        case .dataBrokerMetricsWeeklyStats: return "m_mac_dbp_databroker_weekly_stats"
        case .dataBrokerMetricsMonthlyStats: return "m_mac_dbp_databroker_monthly_stats"

            // Configuration
        case .invalidPayload(let configuration): return "m_mac_dbp_\(configuration.rawValue)_invalid_payload".lowercased()
        case .errorLoadingCachedConfig: return "m_mac_dbp_configuration_error_loading_cached_config"
        case .failedToParsePrivacyConfig: return "m_mac_dbp_configuration_failed_to_parse"

            // Various monitoring pixels
        case .customDataBrokerStatsOptoutSubmit: return "m_mac_dbp_databroker_custom_stats_optoutsubmit"
        case .customGlobalStatsOptoutSubmit: return "m_mac_dbp_custom_stats_optoutsubmit"
        case .weeklyChildBrokerOrphanedOptOuts: return "m_mac_dbp_weekly_child-broker_orphaned-optouts"
        }
    }

    public var params: [String: String]? {
        parameters
    }

    public var parameters: [String: String]? {
        switch self {
        case .error(let error, let dataBroker):
            if case let .actionFailed(actionID, message) = error {
                return ["dataBroker": dataBroker,
                        "name": error.name,
                        "actionID": actionID,
                        "message": message]
            } else {
                return ["dataBroker": dataBroker, "name": error.name]
            }
        case .generalError(_, let functionOccurredIn):
            return ["functionOccurredIn": functionOccurredIn]
        case .parentChildMatches(let parent, let child, let value):
            return ["parent": parent, "child": child, "value": String(value)]
        case .optOutStart(let dataBroker, let attemptId):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString]
        case .optOutEmailGenerate(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutCaptchaParse(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutCaptchaSend(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutCaptchaSolve(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutSubmit(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutEmailReceive(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutEmailConfirm(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutValidate(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutFinish(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutFillForm(let dataBroker, let attemptId, let duration):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration)]
        case .optOutSubmitSuccess(let dataBroker, let attemptId, let duration, let tries, let pattern):
            var params = [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration), Consts.triesKey: String(tries)]
            if let pattern = pattern {
                params[Consts.pattern] = pattern
            }
            return params
        case .optOutSuccess(let dataBroker, let attemptId, let duration, let type):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration), Consts.isParent: String(type.rawValue)]
        case .optOutFailure(let dataBroker, let dataBrokerVersion, let attemptId, let duration, let stage, let tries, let pattern, let actionID):
            var params = [Consts.dataBrokerParamKey: dataBroker, Consts.dataBrokerVersionKey: dataBrokerVersion, Consts.attemptIdParamKey: attemptId.uuidString, Consts.durationParamKey: String(duration), Consts.stageKey: stage, Consts.triesKey: String(tries)]
            if let pattern = pattern {
                params[Consts.pattern] = pattern
            }

            if let actionID = actionID {
                params[Consts.actionIDKey] = actionID
            }

            return params
        case .weeklyReportScanning(let hadNewMatch, let hadReAppereance, let scanCoverage):
            return [Consts.hadNewMatch: hadNewMatch ? "1" : "0", Consts.hadReAppereance: hadReAppereance ? "1" : "0", Consts.scanCoverage: scanCoverage.description]
        case .weeklyReportRemovals(let removals):
            return [Consts.removals: String(removals)]
        case .optOutJobAt7DaysConfirmed(let dataBroker),
                .optOutJobAt7DaysUnconfirmed(let dataBroker),
                .optOutJobAt14DaysConfirmed(let dataBroker),
                .optOutJobAt14DaysUnconfirmed(let dataBroker),
                .optOutJobAt21DaysConfirmed(let dataBroker),
                .optOutJobAt21DaysUnconfirmed(let dataBroker):
            return [Consts.dataBrokerParamKey: dataBroker]
        case .webUILoadingStarted(let environment):
            return [Consts.environmentKey: environment]
        case .webUILoadingSuccess(let environment):
            return [Consts.environmentKey: environment]
        case .webUILoadingFailed(let error):
            return [Consts.errorCategoryKey: error]
        case .backgroundAgentStarted,
                .backgroundAgentStartedStoppingDueToAnotherInstanceRunning,
                .dataBrokerProtectionNotificationSentFirstScanComplete,
                .dataBrokerProtectionNotificationOpenedFirstScanComplete,
                .dataBrokerProtectionNotificationSentFirstRemoval,
                .dataBrokerProtectionNotificationOpenedFirstRemoval,
                .dataBrokerProtectionNotificationScheduled2WeeksCheckIn,
                .dataBrokerProtectionNotificationOpened2WeeksCheckIn,
                .dataBrokerProtectionNotificationSentAllRecordsRemoved,
                .dataBrokerProtectionNotificationOpenedAllRecordsRemoved,
                .dailyActiveUser,
                .weeklyActiveUser,
                .monthlyActiveUser,

                .scanningEventNewMatch,
                .scanningEventReAppearance,
                .homeViewShowNoPermissionError,
                .homeViewShowWebUI,
                .homeViewShowBadPathError,
                .homeViewCTAMoveApplicationClicked,
                .homeViewCTAGrantPermissionClicked,
                .entitlementCheckValid,
                .entitlementCheckInvalid,
                .entitlementCheckError,
                .secureVaultInitError,
                .secureVaultKeyStoreReadError,
                .secureVaultKeyStoreUpdateError,
                .secureVaultError,
                .invalidPayload,
                .failedToParsePrivacyConfig:
            return [:]
        case .ipcServerProfileSavedCalledByApp,
                .ipcServerProfileSavedReceivedByAgent,
                .ipcServerProfileSavedXPCError,
                .ipcServerImmediateScansInterrupted,
                .ipcServerImmediateScansFinishedWithoutError,
                .ipcServerImmediateScansFinishedWithError,
                .ipcServerAppLaunchedCalledByApp,
                .ipcServerAppLaunchedReceivedByAgent,
                .ipcServerAppLaunchedXPCError,
                .ipcServerAppLaunchedScheduledScansBlocked,
                .ipcServerAppLaunchedScheduledScansInterrupted,
                .ipcServerAppLaunchedScheduledScansFinishedWithoutError,
                .ipcServerAppLaunchedScheduledScansFinishedWithError:
            return [Consts.bundleIDParamKey: Bundle.main.bundleIdentifier ?? "nil"]
        case .scanSuccess(let dataBroker, let matchesFound, let duration, let tries, let isImmediateOperation):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.matchesFoundKey: String(matchesFound), Consts.durationParamKey: String(duration), Consts.triesKey: String(tries), Consts.isImmediateOperation: isImmediateOperation.description]
        case .scanFailed(let dataBroker, let dataBrokerVersion, let duration, let tries, let isImmediateOperation):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.dataBrokerVersionKey: dataBrokerVersion, Consts.durationParamKey: String(duration), Consts.triesKey: String(tries), Consts.isImmediateOperation: isImmediateOperation.description]
        case .scanError(let dataBroker, let dataBrokerVersion, let duration, let category, let details, let isImmediateOperation):
            return [Consts.dataBrokerParamKey: dataBroker, Consts.dataBrokerVersionKey: dataBrokerVersion, Consts.durationParamKey: String(duration), Consts.errorCategoryKey: category, Consts.errorDetailsKey: details, Consts.isImmediateOperation: isImmediateOperation.description]
        case .generateEmailHTTPErrorDaily(let statusCode, let environment, let wasOnWaitlist):
            return [Consts.environmentKey: environment,
                    Consts.httpCode: String(statusCode),
                    Consts.wasOnWaitlist: String(wasOnWaitlist)]
        case .emptyAccessTokenDaily(let environment, let wasOnWaitlist, let backendServiceCallSite):
            return [Consts.environmentKey: environment,
                    Consts.wasOnWaitlist: String(wasOnWaitlist),
                    Consts.backendServiceCallSite: backendServiceCallSite.rawValue]
        case .initialScanTotalDuration(let duration, let profileQueries):
            return [Consts.durationInMs: String(duration), Consts.profileQueries: String(profileQueries)]
        case .initialScanSiteLoadDuration(let duration, let hasError, let brokerURL, let sleepDuration):
            return [Consts.durationInMs: String(duration), Consts.hasError: hasError.description, Consts.brokerURL: brokerURL, Consts.sleepDuration: String(sleepDuration)]
        case .initialScanPostLoadingDuration(let duration, let hasError, let brokerURL, let sleepDuration):
            return [Consts.durationInMs: String(duration), Consts.hasError: hasError.description, Consts.brokerURL: brokerURL, Consts.sleepDuration: String(sleepDuration)]
        case .initialScanPreStartDuration(let duration):
            return [Consts.durationInMs: String(duration)]
        case .globalMetricsWeeklyStats(let profilesFound, let optOutsInProgress, let successfulOptOuts, let failedOptOuts, let durationOfFirstOptOut, let numberOfNewRecordsFound),
                        .globalMetricsMonthlyStats(let profilesFound, let optOutsInProgress, let successfulOptOuts, let failedOptOuts, let durationOfFirstOptOut, let numberOfNewRecordsFound):
                    return [Consts.numberOfRecordsFound: String(profilesFound),
                            Consts.numberOfOptOutsInProgress: String(optOutsInProgress),
                            Consts.numberOfSucessfulOptOuts: String(successfulOptOuts),
                            Consts.numberOfOptOutsFailure: String(failedOptOuts),
                            Consts.durationOfFirstOptOut: String(durationOfFirstOptOut),
                            Consts.numberOfNewRecordsFound: String(numberOfNewRecordsFound)]
        case .dataBrokerMetricsWeeklyStats(let dataBrokerURL, let profilesFound, let optOutsInProgress, let successfulOptOuts, let failedOptOuts, let durationOfFirstOptOut, let numberOfNewRecordsFound, let numberOfReappereances),
                     .dataBrokerMetricsMonthlyStats(let dataBrokerURL, let profilesFound, let optOutsInProgress, let successfulOptOuts, let failedOptOuts, let durationOfFirstOptOut, let numberOfNewRecordsFound, let numberOfReappereances):
                   return [Consts.dataBrokerParamKey: dataBrokerURL,
                           Consts.numberOfRecordsFound: String(profilesFound),
                           Consts.numberOfOptOutsInProgress: String(optOutsInProgress),
                           Consts.numberOfSucessfulOptOuts: String(successfulOptOuts),
                           Consts.numberOfOptOutsFailure: String(failedOptOuts),
                           Consts.durationOfFirstOptOut: String(durationOfFirstOptOut),
                           Consts.numberOfNewRecordsFound: String(numberOfNewRecordsFound),
                           Consts.numberOfReappereances: String(numberOfReappereances)]
        case .errorLoadingCachedConfig(let error):
            return [Consts.errorDomainKey: (error as NSError).domain]
        case .customDataBrokerStatsOptoutSubmit(let dataBrokerName, let optOutSubmitSuccessRate):
            return [Consts.dataBrokerParamKey: dataBrokerName,
                    Consts.optOutSubmitSuccessRate: String(optOutSubmitSuccessRate)]
        case .customGlobalStatsOptoutSubmit(let optOutSubmitSuccessRate):
            return [Consts.optOutSubmitSuccessRate: String(optOutSubmitSuccessRate)]
        case .weeklyChildBrokerOrphanedOptOuts(let dataBrokerName, let childParentRecordDifference, let calculatedOrphanedRecords):
            return [Consts.dataBrokerParamKey: dataBrokerName,
                    Consts.childParentRecordDifference: String(childParentRecordDifference),
                    Consts.calculatedOrphanedRecords: String(calculatedOrphanedRecords)]
        }
    }
}

public class DataBrokerProtectionPixelsHandler: EventMapping<DataBrokerProtectionPixels> {

    public init() {
        super.init { event, _, _, _ in
            switch event {
            case .generateEmailHTTPErrorDaily:
                PixelKit.fire(event, frequency: .daily)
            case .emptyAccessTokenDaily:
                PixelKit.fire(event, frequency: .daily)
            case .error(let error, _):
                PixelKit.fire(DebugEvent(event, error: error))
            case .generalError(let error, _):
                PixelKit.fire(DebugEvent(event, error: error))
            case .errorLoadingCachedConfig(let error):
                PixelKit.fire(DebugEvent(event, error: error))
            case .secureVaultInitError(let error),
                    .secureVaultError(let error),
                    .secureVaultKeyStoreReadError(let error),
                    .secureVaultKeyStoreUpdateError(let error),
                    .failedToParsePrivacyConfig(let error):
                PixelKit.fire(DebugEvent(event, error: error))
            case .ipcServerProfileSavedXPCError(error: let error),
                    .ipcServerImmediateScansFinishedWithError(error: let error),
                    .ipcServerAppLaunchedXPCError(error: let error),
                    .ipcServerAppLaunchedScheduledScansFinishedWithError(error: let error):
                PixelKit.fire(DebugEvent(event, error: error), frequency: .legacyDailyAndCount, includeAppVersionParameter: true)
            case .ipcServerProfileSavedCalledByApp,
                    .ipcServerProfileSavedReceivedByAgent,
                    .ipcServerImmediateScansInterrupted,
                    .ipcServerImmediateScansFinishedWithoutError,
                    .ipcServerAppLaunchedCalledByApp,
                    .ipcServerAppLaunchedReceivedByAgent,
                    .ipcServerAppLaunchedScheduledScansBlocked,
                    .ipcServerAppLaunchedScheduledScansInterrupted,
                    .ipcServerAppLaunchedScheduledScansFinishedWithoutError:
                PixelKit.fire(event, frequency: .legacyDailyAndCount, includeAppVersionParameter: true)
            case .parentChildMatches,
                    .optOutStart,
                    .optOutEmailGenerate,
                    .optOutCaptchaParse,
                    .optOutCaptchaSend,
                    .optOutCaptchaSolve,
                    .optOutSubmit,
                    .optOutEmailReceive,
                    .optOutEmailConfirm,
                    .optOutValidate,
                    .optOutFinish,
                    .optOutSubmitSuccess,
                    .optOutFillForm,
                    .optOutSuccess,
                    .optOutFailure,
                    .backgroundAgentStarted,
                    .backgroundAgentStartedStoppingDueToAnotherInstanceRunning,
                    .scanSuccess,
                    .scanFailed,
                    .scanError,
                    .dataBrokerProtectionNotificationSentFirstScanComplete,
                    .dataBrokerProtectionNotificationOpenedFirstScanComplete,
                    .dataBrokerProtectionNotificationSentFirstRemoval,
                    .dataBrokerProtectionNotificationOpenedFirstRemoval,
                    .dataBrokerProtectionNotificationScheduled2WeeksCheckIn,
                    .dataBrokerProtectionNotificationOpened2WeeksCheckIn,
                    .dataBrokerProtectionNotificationSentAllRecordsRemoved,
                    .dataBrokerProtectionNotificationOpenedAllRecordsRemoved,
                    .dailyActiveUser,
                    .weeklyActiveUser,
                    .monthlyActiveUser,
                    .weeklyReportScanning,
                    .weeklyReportRemovals,
                    .optOutJobAt7DaysConfirmed,
                    .optOutJobAt7DaysUnconfirmed,
                    .optOutJobAt14DaysConfirmed,
                    .optOutJobAt14DaysUnconfirmed,
                    .optOutJobAt21DaysConfirmed,
                    .optOutJobAt21DaysUnconfirmed,
                    .scanningEventNewMatch,
                    .scanningEventReAppearance,
                    .webUILoadingFailed,
                    .webUILoadingStarted,
                    .webUILoadingSuccess,
                    .initialScanTotalDuration,
                    .initialScanSiteLoadDuration,
                    .initialScanPostLoadingDuration,
                    .initialScanPreStartDuration,
                    .globalMetricsWeeklyStats,
                    .globalMetricsMonthlyStats,
                    .dataBrokerMetricsWeeklyStats,
                    .dataBrokerMetricsMonthlyStats,
                    .invalidPayload,
                    .customDataBrokerStatsOptoutSubmit,
                    .customGlobalStatsOptoutSubmit,
                    .weeklyChildBrokerOrphanedOptOuts:

                PixelKit.fire(event)

            case .homeViewShowNoPermissionError,
                    .homeViewShowWebUI,
                    .homeViewShowBadPathError,
                    .homeViewCTAMoveApplicationClicked,
                    .homeViewCTAGrantPermissionClicked,
                    .entitlementCheckValid,
                    .entitlementCheckInvalid,
                    .entitlementCheckError:
                PixelKit.fire(event, frequency: .legacyDailyAndCount)

            }
        }
    }

    override init(mapping: @escaping EventMapping<DataBrokerProtectionPixels>.Mapping) {
        fatalError("Use init()")
    }
}
