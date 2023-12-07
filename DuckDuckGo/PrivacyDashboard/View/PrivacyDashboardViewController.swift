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

protocol PrivacyDashboardViewControllerSizeDelegate {

    func privacyDashboardViewControllerDidChange(size: NSSize)
}

final class PrivacyDashboardViewController: NSViewController {

    struct Constants {
        static let initialContentHeight: CGFloat = 489
    }

    /// Type of web page displayed
    enum Mode {
        case privacyDashboard
        case reportBrokenSite
    }

    private var webView: WKWebView!
    let width: CGFloat = 360.0
    private let initMode: Mode

    var source: WebsiteBreakage.Source {
        initMode == .reportBrokenSite ? .appMenu : .dashboard
    }

    private let privacyDashboardController =  PrivacyDashboardController(privacyInfo: nil)
    public let rulesUpdateObserver = ContentBlockingRulesUpdateObserver()
    private let websiteBreakageReporter = WebsiteBreakageReporter()
    private let permissionHandler = PrivacyDashboardPermissionHandler()
    private var preferredMaxHeight: CGFloat = Constants.initialContentHeight
    func setPreferredMaxHeight(_ height: CGFloat) {
        guard height > Constants.initialContentHeight else { return }

        preferredMaxHeight = height
    }

    var sizeDelegate: PrivacyDashboardViewControllerSizeDelegate?

    required init?(coder: NSCoder,
          initMode: Mode) {
        self.initMode = initMode
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        self.initMode = .privacyDashboard
        super.init(coder: coder)
    }

    public func updateTabViewModel(_ tabViewModel: TabViewModel) {

        privacyDashboardController.updatePrivacyInfo(tabViewModel.tab.privacyInfo)
        rulesUpdateObserver.updateTabViewModel(tabViewModel, onPendingUpdates: { [weak self] in
            self?.sendPendingUpdates()
        })
        websiteBreakageReporter.updateTabViewModel(tabViewModel)
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
        tabCollection.appendNewTab(with: .url(url), selected: true)
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
            tabCollection.appendNewTab(with: .preferences(pane: .privacy), selected: true)
        default:
            tabCollection.appendNewTab(with: .anyPreferencePane, selected: true)
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
        sizeDelegate?.privacyDashboardViewControllerDidChange(size: NSSize(width: width, height: CGFloat(height)))
    }
}

// MARK: - PrivacyDashboardReportBrokenSiteDelegate

extension PrivacyDashboardViewController: PrivacyDashboardReportBrokenSiteDelegate {

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboard.PrivacyDashboardController, didRequestSubmitBrokenSiteReportWithCategory category: String, description: String) {
        websiteBreakageReporter.reportBreakage(category: category, description: description, reportFlow: .dashboard)
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboard.PrivacyDashboardController, reportBrokenSiteDidChangeProtectionSwitch protectionState: PrivacyDashboard.ProtectionState) {
        privacyDashboardProtectionSwitchChangeHandler(state: protectionState)
    }
}
