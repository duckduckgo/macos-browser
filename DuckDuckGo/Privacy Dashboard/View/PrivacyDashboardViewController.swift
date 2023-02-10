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

final class PrivacyDashboardViewController: NSViewController {

    struct Constants {
        static let initialContentHeight: CGFloat = 499
    }

    private var webView: WKWebView!
    private var contentHeightConstraint: NSLayoutConstraint!

    private let privacyDashboardController =  PrivacyDashboardController(privacyInfo: nil)
    public let rulesUpdateObserver = ContentBlockingRulesUpdateObserver()
    private let websiteBreakageReporter = WebsiteBreakageReporter()
    private let permissionHandler = PrivacyDashboardPermissionHandler()

    /// Running the resize animation block during the popover animation causes frame hitching.
    /// The animation only needs to run when transitioning between views in the popover, so this is used to track when to run the animation.
    /// This should be set to true any time the popover is displayed (i.e., reset to true when dismissing the popover), and false after the initial resize pass is complete.
    @Published private var shouldAnimateHeightChange: Bool = false

    @Published private var currentContentHeight: Int = Int(Constants.initialContentHeight)
    private var currentContentHeightCancellable: AnyCancellable?

    private var preferredMaxHeight: CGFloat = Constants.initialContentHeight
    func setPreferredMaxHeight(_ height: CGFloat) {
        guard height > Constants.initialContentHeight else { return }

        preferredMaxHeight = height
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
        privacyDashboardController.setup(for: webView)

        setupHeightChangeHandler()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        privacyDashboardController.delegate = self
        privacyDashboardController.preferredLocale = "en" // fixed until app is localised

        webView.reload()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.shouldAnimateHeightChange = true
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        privacyDashboardController.delegate = nil
        shouldAnimateHeightChange = false
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()

        currentContentHeight = Int(Constants.initialContentHeight)
    }

    private func initWebView() {
        let configuration = WKWebViewConfiguration()

#if DEBUG
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif

        let webView = PrivacyDashboardWebView(frame: .zero, configuration: configuration)
        self.webView = webView
        view.addAndLayout(webView)

        view.topAnchor.constraint(equalTo: webView.topAnchor).isActive = true

        contentHeightConstraint = view.heightAnchor.constraint(equalToConstant: Constants.initialContentHeight)
        contentHeightConstraint.isActive = true
    }

    private func setupHeightChangeHandler() {
        currentContentHeightCancellable = $currentContentHeight
            .combineLatest($shouldAnimateHeightChange)
            .removeDuplicates { prev, current in
                prev.0 == current.0
            }
            .sink(receiveValue: { [weak self] (height, shouldAnimate) in
                self?.onHeightChange(height, shouldAnimate: shouldAnimate)
            })
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

    private func onHeightChange(_ height: Int, shouldAnimate: Bool) {
        var height = CGFloat(height)
        if height > self.preferredMaxHeight {
            height = self.preferredMaxHeight
        }

        if shouldAnimate {
            NSAnimationContext.runAnimationGroup { [weak self] context in
                context.duration = 1/3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self?.contentHeightConstraint.animator().constant = height
            }
        } else {
            self.contentHeightConstraint.constant = height
        }
    }
}

extension PrivacyDashboardViewController: PrivacyDashboardControllerDelegate {

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController, didChangeProtectionSwitch isEnabled: Bool) {
        guard let domain = privacyDashboardController.privacyInfo?.url.host else {
            return
        }

        let configuration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig
        if isEnabled && configuration.isUserUnprotected(domain: domain) {
            configuration.userEnabledProtection(forDomain: domain)
        } else {
            configuration.userDisabledProtection(forDomain: domain)
        }

        let completionToken = ContentBlocking.shared.contentBlockingManager.scheduleCompilation()
        rulesUpdateObserver.didStartCompilation(for: domain, token: completionToken)
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

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController, didSetHeight height: Int) {
        currentContentHeight = height
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController, didRequestSubmitBrokenSiteReportWithCategory category: String, description: String) {
        websiteBreakageReporter.reportBreakage(category: category, description: description)
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController, didSetPermission permissionName: String, to state: PermissionAuthorizationState) {
        guard let domain = self.privacyDashboardController.privacyInfo?.url.host else { return }

        permissionHandler.setPermissionAuthorization(authorizationState: state, domain: domain, permissionName: permissionName)
    }

    func privacyDashboardController(_ privacyDashboardController: PrivacyDashboardController, setPermission permissionName: String, paused: Bool) {
        permissionHandler.setPermission(with: permissionName, paused: paused)
    }

}
