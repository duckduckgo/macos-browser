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

    /// Type of web page displayed
    enum Mode {
        case privacyDashboard
        case reportBrokenSite
    }

    private var webView: WKWebView!
    private let initMode: Mode

    var source: WebsiteBreakage.Source {
        initMode == .reportBrokenSite ? .appMenu : .dashboard
    }

    private let privacyDashboardController =  PrivacyDashboardController(privacyInfo: nil)
    public let rulesUpdateObserver = ContentBlockingRulesUpdateObserver()

    private let websiteBreakageReporter: WebsiteBreakageReporter = {
        WebsiteBreakageReporter(pixelHandler: { parameters in
            Pixel.fire(
                .brokenSiteReport,
                withAdditionalParameters: parameters,
                allowedQueryReservedCharacters: WebsiteBreakage.allowedQueryReservedCharacters
            )
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

    required init?(coder: NSCoder, initMode: Mode) {
        self.initMode = initMode
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        self.initMode = .privacyDashboard
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
        privacyDashboardController.setup(for: webView, reportBrokenSiteOnly: initMode == .reportBrokenSite ? true : false)
        privacyDashboardController.privacyDashboardNavigationDelegate = self
        privacyDashboardController.privacyDashboardDelegate = self
        privacyDashboardController.privacyDashboardReportBrokenSiteDelegate = self
        privacyDashboardController.preferredLocale = "en" // fixed until app is localised
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

        dismiss()

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

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController, didChangeProtectionSwitch protectionState: ProtectionState) {
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
            tabCollection.appendNewTab(with: .settings(pane: .privacy), selected: true)
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
        do {
            let websiteBreakage = try makeWebsiteBreakage(category: category, description: description)
            try websiteBreakageReporter.report(breakage: websiteBreakage)
        } catch {
            os_log("Failed to generate or send the website breakage report: \(error.localizedDescription)", type: .error)
        }
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboard.PrivacyDashboardController,
                                    reportBrokenSiteDidChangeProtectionSwitch protectionState: PrivacyDashboard.ProtectionState) {

        privacyDashboardProtectionSwitchChangeHandler(state: protectionState)
    }
}

// MARK: - Breakage

extension PrivacyDashboardViewController {

    enum WebsiteBreakageError: Error {
        case failedToFetchTheCurrentURL
    }

    private func makeWebsiteBreakage(category: String, description: String) throws -> WebsiteBreakage {

        // ⚠️ To limit privacy risk, site URL is trimmed to not include query and fragment
        guard let currentTab = tabViewModel?.tab,
            let currentURL = currentTab.content.url?.trimmingQueryItemsAndFragment() else {
            throw WebsiteBreakageError.failedToFetchTheCurrentURL
        }
        let blockedTrackerDomains = currentTab.privacyInfo?.trackerInfo.trackersBlocked.compactMap { $0.domain } ?? []
        let installedSurrogates = currentTab.privacyInfo?.trackerInfo.installedSurrogates.map {$0} ?? []
        let ampURL = currentTab.linkProtection.lastAMPURLString ?? ""
        let urlParametersRemoved = currentTab.linkProtection.urlParametersRemoved

        // current domain's protection status
        let configuration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig
        let protectionsState = configuration.isFeature(.contentBlocking, enabledForDomain: currentTab.content.url?.host)

        let websiteBreakage = WebsiteBreakage(siteUrl: currentURL,
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
                                              error: nil,
                                              httpStatusCode: nil)
        return websiteBreakage
    }
}
