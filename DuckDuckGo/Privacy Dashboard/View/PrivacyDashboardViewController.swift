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
        static let initialContentHeight: CGFloat = 452
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
    private var skipLayoutAnimation = true
    
    private var preferredMaxHeight: CGFloat = Constants.initialContentHeight
    func setPreferredMaxHeight(_ height: CGFloat) {
        guard height > Constants.initialContentHeight else { return }
        
        preferredMaxHeight = height
        if let webView = webView {
//            webView.reload()
        }
    }
    
    public func updateTabViewModel(_ tabViewModel: TabViewModel) {
        privacyDashboardController.updatePrivacyInfo(tabViewModel.tab.privacyInfo)
        
        rulesUpdateObserver.updateTabViewModel(tabViewModel, onPendingUpdates: { [weak self] in
            self?.sendPendingUpdates()
        })
        
        websiteBreakageReporter.updateTabViewModel(tabViewModel)
        
        permissionHandler.updateTabViewModel(tabViewModel) { [weak self] allowedPermissions in
            self?.privacyDashboardController.updateAllowedPermissions(allowedPermissions)
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        initWebView()
        privacyDashboardController.setup(for: webView)
        setupPrivacyDashboardControllerHandlers()
        setupHeighChangeHandler()
    }
    
    override func viewWillAppear() {
        skipLayoutAnimation = true
//        privacyDashboardController.setup(for: webView)
        privacyDashboardController.preferredLocale = "en"
        webView.reload()
    }
    
    override func viewDidAppear() {
        skipLayoutAnimation = true
    }

    override func viewWillDisappear() {
//        privacyDashboardController.cleanUp()

//        contentHeightConstraint.constant = Constants.initialContentHeight
//        skipLayoutAnimation = true
    }
    
    override func viewDidDisappear() {
        contentHeightConstraint.constant = Constants.initialContentHeight
        skipLayoutAnimation = true
        demandedHeight.send(Int(Constants.initialContentHeight))
        skipLayoutAnimation = true
    }
    
    private func initWebView() {
        let configuration = WKWebViewConfiguration()

#if DEBUG
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif

        let webView = PrivacyDashboardWebView(frame: .zero, configuration: configuration)
        self.webView = webView
        view.addAndLayout(webView)

        contentHeightConstraint = view.heightAnchor.constraint(equalToConstant: Constants.initialContentHeight)
        contentHeightConstraint.isActive = true
    }
    
    let demandedHeight: CurrentValueSubject<Int, Never> = CurrentValueSubject(Int(Constants.initialContentHeight))
    var heightSink: AnyCancellable?
    
    private func setupHeighChangeHandler() {
        heightSink = demandedHeight
            .removeDuplicates()
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink(receiveValue: { [weak self] height in
                Swift.print("new height: \(height)")
                self?.onHeightChange(height)
        })
    }
    
    private func setupPrivacyDashboardControllerHandlers() {
        privacyDashboardController.onProtectionSwitchChange = { [weak self] isEnabled in
            guard let domain = self?.privacyDashboardController.privacyInfo?.url.host else {
                return
            }

            let configuration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig
            if isEnabled && configuration.isUserUnprotected(domain: domain) {
                configuration.userEnabledProtection(forDomain: domain)
            } else {
                configuration.userDisabledProtection(forDomain: domain)
            }

            let completionToken = ContentBlocking.shared.contentBlockingManager.scheduleCompilation()
            self?.rulesUpdateObserver.didStartCompilation(for: domain, token: completionToken)
        }
        
        privacyDashboardController.onHeightChange = { [weak self] height in
            guard let self = self else { return }
            self.demandedHeight.send(height)
        }
        
        privacyDashboardController.onCloseTapped = { }
        
        privacyDashboardController.onShowReportBrokenSiteTapped = { }
        
        privacyDashboardController.onSubmitBrokenSiteReportWithCategory = { [weak self] category, description in
            self?.websiteBreakageReporter.reportBreakage(category: category, description: description)
        }
        
        privacyDashboardController.onOpenUrlInNewTab = { url in
            guard let tabCollection = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel
            else {
                assertionFailure("could not access shared tabCollectionViewModel")
                return
            }
            tabCollection.appendNewTab(with: .url(url), selected: true)
        }
    }
    
    public func isPendingUpdates() -> Bool {
        return !rulesUpdateObserver.pendingUpdates.isEmpty
    }

    private func sendPendingUpdates() {
        guard let domain = privacyDashboardController.privacyInfo?.url.host else {
            assertionFailure("PrivacyDashboardViewController: no domain available")
            return
        }

        let isPending = rulesUpdateObserver.pendingUpdates.values.contains(domain)
        if isPending {
            privacyDashboardController.didStartRulesCompilation()
        } else {
            privacyDashboardController.didFinishRulesCompilation()
        }
    }
    
    private func onHeightChange(_ height: Int) {
        Swift.print("height change \(height)")

        var height = CGFloat(height)
        if height > self.preferredMaxHeight {
            height = self.preferredMaxHeight
        }
         
        if self.skipLayoutAnimation {
            Swift.print(" - skipping animation")
            self.contentHeightConstraint.constant = height
            self.skipLayoutAnimation = false
        } else {
            Swift.print(" - animating")
            NSAnimationContext.runAnimationGroup { [weak self] context in
                context.duration = 1/3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self?.contentHeightConstraint.animator().constant = height
            }
        }
    }
}

extension PrivacyDashboardViewController {

    func userScript(_ userScript: OLDPrivacyDashboardUserScript, didSetPermission permission: PermissionType, to state: PermissionAuthorizationState) {
//        guard let domain = tabViewModel?.tab.content.url?.host else {
//            assertionFailure("PrivacyDashboardViewController: no domain available")
//            return
//        }
//
//        PermissionManager.shared.setPermission(state.persistedPermissionDecision, forDomain: domain, permissionType: permission)
    }

    func userScript(_ userScript: OLDPrivacyDashboardUserScript, setPermission permission: PermissionType, paused: Bool) {
//        tabViewModel?.tab.permissions.set([permission], muted: paused)
    }

}
