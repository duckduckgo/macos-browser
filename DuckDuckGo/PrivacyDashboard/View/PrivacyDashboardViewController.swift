//
//  PrivacyDashboardViewController.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import Cocoa
import WebKit
import Combine
import BrowserServicesKit
import PrivacyDashboard
import Common

protocol PrivacyDashboardViewControllerSizeDelegate: AnyObject {

    func privacyDashboardViewControllerDidChange(size: NSSize)
}

final class PrivacyDashboardViewController: NSViewController {

    struct Constants {
        static let initialContentHeight: CGFloat = 489.0
        static let reportBrokenSiteInitialContentHeight = 587.0 + 28.0
        static let initialContentWidth: CGFloat = 360.0
    }

    private var webView: WKWebView!
    private let privacyDashboardController: PrivacyDashboardController
    private var privacyDashboardDidTriggerDismiss: Bool = false

    public let rulesUpdateObserver = ContentBlockingRulesUpdateObserver()

    private let brokenSiteReporter: BrokenSiteReporter = {
        BrokenSiteReporter(pixelHandler: { parameters in
            Pixel.fire(
                .brokenSiteReport,
                withAdditionalParameters: parameters,
                allowedQueryReservedCharacters: BrokenSiteReport.allowedQueryReservedCharacters
            )
        }, keyValueStoring: UserDefaults.standard)
    }()

    private let toggleProtectionsOffReporter: BrokenSiteReporter = {
        BrokenSiteReporter(pixelHandler: { parameters in
            Pixel.fire(
                .protectionToggledOffBreakageReport,
                withAdditionalParameters: parameters,
                allowedQueryReservedCharacters: BrokenSiteReport.allowedQueryReservedCharacters)
        }, keyValueStoring: UserDefaults.standard)
    }()

    private let toggleReportEvents = EventMapping<ToggleReportEvents> { event, _, parameters, _ in
        let domainEvent: Pixel.Event
        switch event {
        case .toggleReportDismiss: domainEvent = .toggleReportDismiss
        case .toggleReportDoNotSend: domainEvent = .toggleReportDoNotSend
        }
        Pixel.fire(domainEvent, withAdditionalParameters: parameters)
    }

    private let permissionHandler = PrivacyDashboardPermissionHandler()
    private var preferredMaxHeight: CGFloat = Constants.initialContentHeight
    func setPreferredMaxHeight(_ height: CGFloat) {
        guard height > Constants.initialContentHeight else { return }
        preferredMaxHeight = height
    }
    var sizeDelegate: PrivacyDashboardViewControllerSizeDelegate?
    private weak var tabViewModel: TabViewModel?

    required init?(coder: NSCoder,
                   privacyInfo: PrivacyInfo?,
                   dashboardMode: PrivacyDashboardMode,
                   privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager) {
        self.privacyDashboardController = PrivacyDashboardController(privacyInfo: privacyInfo,
                                                                     dashboardMode: dashboardMode,
                                                                     privacyConfigurationManager: privacyConfigurationManager,
                                                                     eventMapping: toggleReportEvents)
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        self.privacyDashboardController = PrivacyDashboardController(privacyInfo: nil,
                                                                     dashboardMode: .dashboard,
                                                                     privacyConfigurationManager: ContentBlocking.shared.privacyConfigurationManager,
                                                                     eventMapping: toggleReportEvents)
        super.init(coder: coder)
    }

    public func updateTabViewModel(_ tabViewModel: TabViewModel) {
        self.tabViewModel = tabViewModel
        privacyDashboardController.updatePrivacyInfo(tabViewModel.tab.privacyInfo)
        rulesUpdateObserver.updateTabViewModel(tabViewModel, onPendingUpdates: { [weak self] in
            self?.sendPendingUpdates()
        })
        permissionHandler.updateTabViewModel(tabViewModel) { [weak self] allowedPermissions in
            self?.privacyDashboardController.allowedPermissions = allowedPermissions
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        initWebView()
        privacyDashboardController.setup(for: webView)
        privacyDashboardController.privacyDashboardNavigationDelegate = self
        privacyDashboardController.privacyDashboardDelegate = self
        privacyDashboardController.privacyDashboardReportBrokenSiteDelegate = self
        privacyDashboardController.privacyDashboardToggleReportDelegate = self
        privacyDashboardController.preferredLocale = Bundle.main.preferredLocalizations.first
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        if !privacyDashboardDidTriggerDismiss {
            privacyDashboardController.handleViewWillDisappear()
        }
    }

    private func initWebView() {
        let configuration = WKWebViewConfiguration()
#if DEBUG
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif
        let webView = PrivacyDashboardWebView(frame: .zero, configuration: configuration)
        self.webView = webView
        view.addAndLayout(webView)

        webView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        webView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0).isActive = true
        webView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true

#if DEBUG
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        } else {
            // Fallback on earlier versions
        }
#endif
    }

    public func isPendingUpdates() -> Bool {
        return !rulesUpdateObserver.pendingUpdates.isEmpty
    }

    private func sendPendingUpdates() {

        if isPendingUpdatesForCurrentDomain() {
            privacyDashboardController.didStartRulesCompilation()
        } else {
            privacyDashboardController.didFinishRulesCompilation()
        }
    }

    private func isPendingUpdatesForCurrentDomain() -> Bool {
        guard let domain = privacyDashboardController.privacyInfo?.url.host else { return false }
        return rulesUpdateObserver.pendingUpdates.values.contains(domain)
    }

    private func privacyDashboardProtectionSwitchChangeHandler(state: ProtectionState) {
        privacyDashboardDidTriggerDismiss = true
        guard let domain = privacyDashboardController.privacyInfo?.url.host else {
            return
        }

        let configuration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig
        if state.isProtected && configuration.isUserUnprotected(domain: domain) {
            configuration.userEnabledProtection(forDomain: domain)
            Pixel.fire(.dashboardProtectionAllowlistRemove(triggerOrigin: state.eventOrigin.screen.rawValue), includeAppVersionParameter: false)
        } else {
            configuration.userDisabledProtection(forDomain: domain)
            Pixel.fire(.dashboardProtectionAllowlistAdd(triggerOrigin: state.eventOrigin.screen.rawValue), includeAppVersionParameter: false)
        }

        let completionToken = ContentBlocking.shared.contentBlockingManager.scheduleCompilation()
        rulesUpdateObserver.startCompilation(for: domain, token: completionToken)
    }
}

// MARK: - PrivacyDashboardControllerDelegate

extension PrivacyDashboardViewController: PrivacyDashboardControllerDelegate {

    func privacyDashboardControllerDidRequestShowReportBrokenSite(_ privacyDashboardController: PrivacyDashboard.PrivacyDashboardController) {
        // Not used in macOS: Pixel.fire(.privacyDashboardReportBrokenSite)
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController,
                                    didChangeProtectionSwitch protectionState: ProtectionState,
                                    didSendReport: Bool) {
        privacyDashboardProtectionSwitchChangeHandler(state: protectionState)
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController, didRequestOpenUrlInNewTab url: URL) {
        guard let tabCollection = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel
        else {
            assertionFailure("could not access shared tabCollectionViewModel")
            return
        }
        tabCollection.appendNewTab(with: .url(url, source: .ui), selected: true)
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboard.PrivacyDashboardController,
                                    didRequestOpenSettings target: PrivacyDashboard.PrivacyDashboardOpenSettingsTarget) {
        guard let tabCollection = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel
        else {
            assertionFailure("could not access shared tabCollectionViewModel")
            return
        }

        switch target {
        case .cookiePopupManagement:
            tabCollection.appendNewTab(with: .settings(pane: .dataClearing), selected: true)
        default:
            tabCollection.appendNewTab(with: .anySettingsPane, selected: true)
        }
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController, didSetPermission permissionName: String, to state: PermissionAuthorizationState) {
        guard let domain = self.privacyDashboardController.privacyInfo?.url.host else { return }
        permissionHandler.setPermissionAuthorization(authorizationState: state, domain: domain, permissionName: permissionName)
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController, setPermission permissionName: String, paused: Bool) {
        permissionHandler.setPermission(with: permissionName, paused: paused)
    }
}

// MARK: - PrivacyDashboardNavigationDelegate

extension PrivacyDashboardViewController: PrivacyDashboardNavigationDelegate {

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboard.PrivacyDashboardController, didSetHeight height: Int) {
        sizeDelegate?.privacyDashboardViewControllerDidChange(size: NSSize(width: Constants.initialContentWidth, height: CGFloat(height)))
    }

    func privacyDashboardControllerDidTapClose(_ privacyDashboardController: PrivacyDashboard.PrivacyDashboardController) {
        dismiss()
    }
}

// MARK: - PrivacyDashboardReportBrokenSiteDelegate

extension PrivacyDashboardViewController: PrivacyDashboardReportBrokenSiteDelegate {

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboard.PrivacyDashboardController,
                                    didRequestSubmitBrokenSiteReportWithCategory category: String,
                                    description: String) {
        let source: BrokenSiteReport.Source = privacyDashboardController.initDashboardMode == .report ? .appMenu : .dashboard
        Task { @MainActor in
            do {
                let report = try await makeBrokenSiteReport(category: category, description: description, source: source)
                try brokenSiteReporter.report(report, reportMode: .regular)
            } catch {
                os_log("Failed to generate or send the broken site report: \(error.localizedDescription)", type: .error)
            }
        }
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboard.PrivacyDashboardController,
                                    reportBrokenSiteDidChangeProtectionSwitch protectionState: PrivacyDashboard.ProtectionState) {

        privacyDashboardProtectionSwitchChangeHandler(state: protectionState)
    }
}

// MARK: - PrivacyDashboardToggleReportDelegate

extension PrivacyDashboardViewController: PrivacyDashboardToggleReportDelegate {

   func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController,
                                   didRequestSubmitToggleReportWithSource source: BrokenSiteReport.Source,
                                   didOpenReportInfo: Bool,
                                   toggleReportCounter: Int?) {
       Task { @MainActor in
           do {
               let report = try await makeBrokenSiteReport(source: source,
                                                           didOpenReportInfo: didOpenReportInfo,
                                                           toggleReportCounter: toggleReportCounter)
               try toggleProtectionsOffReporter.report(report, reportMode: .toggle)
           } catch {
               os_log("Failed to generate or send the broken site report: %@", type: .error, error.localizedDescription)
           }
       }
   }

}

// MARK: - Breakage

extension PrivacyDashboardViewController {

    enum BrokenSiteReportError: Error {
        case failedToFetchTheCurrentURL
    }

    private func calculateWebVitals(performanceMetrics: PerformanceMetricsSubfeature?, privacyConfig: PrivacyConfiguration) async -> [Double]? {
        var webVitalsResult: [Double]?
        if privacyConfig.isEnabled(featureKey: .performanceMetrics) {
            webVitalsResult = await withCheckedContinuation({ continuation in
                guard let performanceMetrics else { continuation.resume(returning: nil); return }
                performanceMetrics.notifyHandler { result in
                    continuation.resume(returning: result)
                }
            })
        }

        return webVitalsResult
    }

    private func makeBrokenSiteReport(category: String = "",
                                      description: String = "",
                                      source: BrokenSiteReport.Source,
                                      didOpenReportInfo: Bool = false,
                                      toggleReportCounter: Int? = nil) async throws -> BrokenSiteReport {

        // ⚠️ To limit privacy risk, site URL is trimmed to not include query and fragment
        guard let currentTab = tabViewModel?.tab,
            let currentURL = currentTab.content.url?.trimmingQueryItemsAndFragment() else {
            throw BrokenSiteReportError.failedToFetchTheCurrentURL
        }
        let blockedTrackerDomains = currentTab.privacyInfo?.trackerInfo.trackersBlocked.compactMap { $0.domain } ?? []
        let installedSurrogates = currentTab.privacyInfo?.trackerInfo.installedSurrogates.map {$0} ?? []
        let ampURL = currentTab.linkProtection.lastAMPURLString ?? ""
        let urlParametersRemoved = currentTab.linkProtection.urlParametersRemoved

        // current domain's protection status
        let configuration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig
        let protectionsState = configuration.isFeature(.contentBlocking, enabledForDomain: currentTab.content.url?.host)

        let webVitals = await calculateWebVitals(performanceMetrics: currentTab.performanceMetrics, privacyConfig: configuration)

        var errors: [Error]?
        var statusCodes: [Int]?
        if let error = currentTab.lastWebError {
            errors = [error]
        }
        if let httpStatusCode = currentTab.lastHttpStatusCode {
            statusCodes = [httpStatusCode]
        }

        let websiteBreakage = BrokenSiteReport(siteUrl: currentURL,
                                               category: category.lowercased(),
                                               description: description,
                                               osVersion: "\(ProcessInfo.processInfo.operatingSystemVersion)",
                                               manufacturer: "Apple",
                                               upgradedHttps: currentTab.privacyInfo?.connectionUpgradedTo != nil,
                                               tdsETag: ContentBlocking.shared.contentBlockingManager.currentRules.first?.etag,
                                               blockedTrackerDomains: blockedTrackerDomains,
                                               installedSurrogates: installedSurrogates,
                                               isGPCEnabled: WebTrackingProtectionPreferences.shared.isGPCEnabled,
                                               ampURL: ampURL,
                                               urlParametersRemoved: urlParametersRemoved,
                                               protectionsState: protectionsState,
                                               reportFlow: source,
                                               errors: errors,
                                               httpStatusCodes: statusCodes,
                                               openerContext: currentTab.inferredOpenerContext,
                                               vpnOn: currentTab.tunnelController.isConnected,
                                               jsPerformance: webVitals,
                                               userRefreshCount: currentTab.refreshCountSinceLoad,
                                               didOpenReportInfo: didOpenReportInfo,
                                               toggleReportCounter: toggleReportCounter)
        return websiteBreakage
    }
}
