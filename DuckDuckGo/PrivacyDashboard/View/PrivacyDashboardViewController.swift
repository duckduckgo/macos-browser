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
import PixelKit
import PixelExperimentKit
import os.log

protocol PrivacyDashboardViewControllerSizeDelegate: AnyObject {

    func privacyDashboardViewControllerDidChange(size: NSSize)
}

final class PrivacyDashboardViewController: NSViewController {

    struct Constants {
        static let initialContentHeight: CGFloat = 489.0
        static let reportBrokenSiteInitialContentHeight = 406.0 + 28.0
        static let initialContentWidth: CGFloat = 360.0
    }

    private var webView: WKWebView!
    private let privacyDashboardController: PrivacyDashboardController
    private var privacyDashboardDidTriggerDismiss: Bool = false

    public let rulesUpdateObserver = ContentBlockingRulesUpdateObserver()

    private let brokenSiteReporter: BrokenSiteReporter = {
        BrokenSiteReporter(pixelHandler: { parameters in
            let privacyConfigurationManager = ContentBlocking.shared.privacyConfigurationManager
            var updatedParameters = parameters
            PixelKit.fire(NonStandardEvent(NonStandardPixel.brokenSiteReport),
                          withAdditionalParameters: updatedParameters,
                          allowedQueryReservedCharacters: BrokenSiteReport.allowedQueryReservedCharacters)
        }, keyValueStoring: UserDefaults.standard)
    }()

    private let toggleProtectionsOffReporter: BrokenSiteReporter = {
        BrokenSiteReporter(pixelHandler: { parameters in
            PixelKit.fire(GeneralPixel.protectionToggledOffBreakageReport,
                          withAdditionalParameters: parameters,
                          allowedQueryReservedCharacters: BrokenSiteReport.allowedQueryReservedCharacters)
        }, keyValueStoring: UserDefaults.standard)
    }()

    private let permissionHandler = PrivacyDashboardPermissionHandler()
    private var preferredMaxHeight: CGFloat = Constants.initialContentHeight
    func setPreferredMaxHeight(_ height: CGFloat) {
        guard height > Constants.initialContentHeight else { return }
        preferredMaxHeight = height
    }
    var sizeDelegate: PrivacyDashboardViewControllerSizeDelegate?
    private weak var tabViewModel: TabViewModel?

    private let privacyDashboardEvents = EventMapping<PrivacyDashboardEvents> { event, _, parameters, _ in
        let domainEvent: NonStandardPixel
        switch event {
        case .showReportBrokenSite: domainEvent = .brokenSiteReportShown
        case .reportBrokenSiteShown: domainEvent = .brokenSiteReportShown
        case .reportBrokenSiteSent: domainEvent = .brokenSiteReportSent
        }
        if let parameters {
            PixelKit.fire(NonStandardEvent(domainEvent), withAdditionalParameters: parameters)
        } else {
            PixelKit.fire(NonStandardEvent(domainEvent))
        }
    }

    init(privacyInfo: PrivacyInfo? = nil,
         entryPoint: PrivacyDashboardEntryPoint = .dashboard,
         privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager) {
        let toggleReportingConfiguration = ToggleReportingConfiguration(privacyConfigurationManager: privacyConfigurationManager)
        let toggleReportingFeature = ToggleReportingFeature(toggleReportingConfiguration: toggleReportingConfiguration)
        let toggleReportingManager = ToggleReportingManager(feature: toggleReportingFeature)
        self.privacyDashboardController = PrivacyDashboardController(privacyInfo: privacyInfo,
                                                                     entryPoint: entryPoint,
                                                                     toggleReportingManager: toggleReportingManager,
                                                                     eventMapping: privacyDashboardEvents)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
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

    override func loadView() {
        view = ColorView(frame: NSRect(x: 0, y: 0, width: 360, height: 489), backgroundColor: NSColor(named: "PopoverBackgroundColor"))
        initWebView()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        privacyDashboardController.setup(for: webView)
        privacyDashboardController.delegate = self
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
        webView.setValue(false, forKey: "drawsBackground")
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
            PixelKit.fire(NonStandardEvent(GeneralPixel.dashboardProtectionAllowlistRemove(triggerOrigin: state.eventOrigin.screen.rawValue)))
        } else {
            configuration.userDisabledProtection(forDomain: domain)
            PixelKit.fire(NonStandardEvent(GeneralPixel.dashboardProtectionAllowlistAdd(triggerOrigin: state.eventOrigin.screen.rawValue)))
            let tdsEtag = ContentBlocking.shared.trackerDataManager.fetchedData?.etag ?? ""
            TDSOverrideExperimentMetrics.fireTDSExperimentMetric(metricType: .privacyToggleUsed, etag: tdsEtag) { parameters in
                PixelKit.fire(GeneralPixel.debugBreakageExperiment, frequency: .uniqueByName, withAdditionalParameters: parameters)
            }
        }

        let completionToken = ContentBlocking.shared.contentBlockingManager.scheduleCompilation()
        rulesUpdateObserver.startCompilation(for: domain, token: completionToken)
    }
}

// MARK: - PrivacyDashboardControllerDelegate

extension PrivacyDashboardViewController: PrivacyDashboardControllerDelegate {

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

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController,
                                    didRequestOpenSettings target: PrivacyDashboardOpenSettingsTarget) {
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

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController,
                                    didSetPermission permissionName: String,
                                    to state: PermissionAuthorizationState) {
        guard let domain = self.privacyDashboardController.privacyInfo?.url.host else { return }
        permissionHandler.setPermissionAuthorization(authorizationState: state, domain: domain, permissionName: permissionName)
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController, setPermission permissionName: String, paused: Bool) {
        permissionHandler.setPermission(with: permissionName, paused: paused)
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController, didSetHeight height: Int) {
        sizeDelegate?.privacyDashboardViewControllerDidChange(size: NSSize(width: Constants.initialContentWidth, height: CGFloat(height)))
    }

    func privacyDashboardControllerDidRequestClose(_ privacyDashboardController: PrivacyDashboardController) {
        dismiss()
    }

    func privacyDashboardControllerDidRequestShowGeneralFeedback(_ privacyDashboardController: PrivacyDashboardController) {
        dismiss()
        FeedbackPresenter.presentFeedbackForm()
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController,
                                    didRequestSubmitBrokenSiteReportWithCategory category: String,
                                    description: String) {
        Task { @MainActor in
            do {
                let report = try await makeBrokenSiteReport(category: category, description: description, source: privacyDashboardController.source)
                try brokenSiteReporter.report(report, reportMode: .regular)
            } catch {
                Logger.general.error("Failed to generate or send the broken site report: \(error.localizedDescription)")
            }
        }
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController,
                                    reportBrokenSiteDidChangeProtectionSwitch protectionState: PrivacyDashboard.ProtectionState) {

        privacyDashboardProtectionSwitchChangeHandler(state: protectionState)
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController,
                                    didRequestSubmitToggleReportWithSource source: BrokenSiteReport.Source) {
        Task { @MainActor in
            do {
                let report = try await makeBrokenSiteReport(source: source)
                try toggleProtectionsOffReporter.report(report, reportMode: .toggle)
            } catch {
                Logger.general.error("Failed to generate or send the broken site report: \(error.localizedDescription)")
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
                                      source: BrokenSiteReport.Source) async throws -> BrokenSiteReport {

        // ⚠️ To limit privacy risk, site URL is trimmed to not include query and fragment
        guard let currentTab = tabViewModel?.tab,
            let currentURL = currentTab.content.urlForWebView?.trimmingQueryItemsAndFragment() else {
            throw BrokenSiteReportError.failedToFetchTheCurrentURL
        }
        let blockedTrackerDomains = currentTab.privacyInfo?.trackerInfo.trackersBlocked.compactMap { $0.domain } ?? []
        let installedSurrogates = currentTab.privacyInfo?.trackerInfo.installedSurrogates.map {$0} ?? []
        let ampURL = currentTab.linkProtection.lastAMPURLString ?? ""
        let urlParametersRemoved = currentTab.linkProtection.urlParametersRemoved

        // current domain's protection status
        let configuration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig
        let protectionsState = configuration.isFeature(.contentBlocking, enabledForDomain: currentTab.content.urlForWebView?.host)

        let webVitals = await calculateWebVitals(performanceMetrics: currentTab.brokenSiteInfo?.performanceMetrics, privacyConfig: configuration)

        var errors: [Error]?
        var statusCodes: [Int]?
        if let error = currentTab.brokenSiteInfo?.lastWebError {
            errors = [error]
        }
        if let httpStatusCode = currentTab.brokenSiteInfo?.lastHttpStatusCode {
            statusCodes = [httpStatusCode]
        }

        let websiteBreakage = BrokenSiteReport(siteUrl: currentURL,
                                               category: category.lowercased(),
                                               description: description,
                                               osVersion: "\(ProcessInfo.processInfo.operatingSystemVersion)",
                                               manufacturer: "Apple",
                                               upgradedHttps: currentTab.privacyInfo?.connectionUpgradedTo != nil,
                                               tdsETag: ContentBlocking.shared.contentBlockingManager.currentRules.first?.etag,
                                               configVersion: configuration.version,
                                               blockedTrackerDomains: blockedTrackerDomains,
                                               installedSurrogates: installedSurrogates,
                                               isGPCEnabled: WebTrackingProtectionPreferences.shared.isGPCEnabled,
                                               ampURL: ampURL,
                                               urlParametersRemoved: urlParametersRemoved,
                                               protectionsState: protectionsState,
                                               reportFlow: source,
                                               errors: errors,
                                               httpStatusCodes: statusCodes,
                                               openerContext: currentTab.brokenSiteInfo?.inferredOpenerContext,
                                               vpnOn: currentTab.networkProtection?.tunnelController.isConnected ?? false,
                                               jsPerformance: webVitals,
                                               userRefreshCount: currentTab.brokenSiteInfo?.refreshCountSinceLoad ?? -1)
        return websiteBreakage
    }
}
