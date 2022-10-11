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
    private let privacyDashboardScript = PrivacyDashboardUserScript()
    private var cancellables = Set<AnyCancellable>()
    @Published var pendingUpdates = [String: String]()

    weak var tabViewModel: TabViewModel?
    var serverTrustViewModel: ServerTrustViewModel?
    
    private var contentBlockinRulesUpdatedCancellable: AnyCancellable?
    
    /// Running the resize animation block during the popover animation causes frame hitching.
    /// The animation only needs to run when transitioning between views in the popover, so this is used to track when to run the animation.
    /// This should be set to true any time the popover is displayed (i.e., reset to true when dismissing the popover), and false after the initial resize pass is complete.
    private var skipLayoutAnimation = true
    
    private var preferredMaxHeight: CGFloat = Constants.initialContentHeight
    func setPreferredMaxHeight(_ height: CGFloat) {
        guard height > Constants.initialContentHeight else { return }
        
        preferredMaxHeight = height
        if let webView = webView {
            webView.reload()
        }
    }

    override func viewDidLoad() {
        privacyDashboardScript.delegate = self
        initWebView()
        webView.configuration.userContentController.addHandlerNoContentWorld(privacyDashboardScript)
    }

    private func prepareContentBlockingCancellable<Pub: Publisher>(publisher: Pub)
    where Pub.Output == [ContentBlockerRulesManager.CompletionToken], Pub.Failure == Never {

        publisher.receive(on: RunLoop.main).sink { [weak self] completionTokens in
            dispatchPrecondition(condition: .onQueue(.main))

            guard let self = self, !self.pendingUpdates.isEmpty else { return }

            var didUpdate = false
            for token in completionTokens {
                if self.pendingUpdates.removeValue(forKey: token) != nil {
                    didUpdate = true
                }
            }

            if didUpdate {
                self.sendPendingUpdates()
                self.tabViewModel?.reload()
            }
        }.store(in: &cancellables)
    }

    override func viewWillAppear() {
        guard let tabViewModel = tabViewModel else { return }

        // This is part of shared logic pasted from the dashboard package
        guard let url = Bundle.privacyDashboardURL else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent().deletingLastPathComponent())
        //
        
        prepareContentBlockingCancellable(publisher: tabViewModel.tab.cbrCompletionTokensPublisher)
    }

    override func viewWillDisappear() {
        contentHeightConstraint.constant = Constants.initialContentHeight
        cancellables.removeAll()
        skipLayoutAnimation = true
    }

    public func isPendingUpdates() -> Bool {
        return !pendingUpdates.isEmpty
    }

    private func initWebView() {
        let configuration = WKWebViewConfiguration()

#if DEBUG
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif

        let webView = PrivacyDashboardWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        view.addAndLayout(webView)

        contentHeightConstraint = view.heightAnchor.constraint(equalToConstant: Constants.initialContentHeight)
        contentHeightConstraint.isActive = true
    }

    private func subscribeToPermissions() {
        tabViewModel?.$usedPermissions.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updatePermissions()
        }.store(in: &cancellables)

    }

    private func updatePermissions() {
        guard let usedPermissions = tabViewModel?.usedPermissions else {
            assertionFailure("PrivacyDashboardViewController: tabViewModel not set")
            return
        }
        guard let domain = tabViewModel?.tab.content.url?.host else {
            privacyDashboardScript.setPermissions(Permissions(), authorizationState: [], domain: "", in: webView)
            return
        }

        let authState: PrivacyDashboardUserScript.AuthorizationState
        authState = PermissionManager.shared.persistedPermissionTypes.union(usedPermissions.keys).compactMap { permissionType in
            guard PermissionManager.shared.hasPermissionPersisted(forDomain: domain, permissionType: permissionType)
                    || usedPermissions[permissionType] != nil
            else {
                return nil
            }
            let decision = PermissionManager.shared.permission(forDomain: domain, permissionType: permissionType)
            return (permissionType, PermissionAuthorizationState(decision: decision))
        }

        privacyDashboardScript.setPermissions(usedPermissions, authorizationState: authState, domain: domain, in: webView)
    }

    private func subscribeToConnectionUpgradedTo() {
        tabViewModel?.tab.$connectionUpgradedTo
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] connectionUpgradedTo in
                guard let self = self else { return }
                let upgradedHttps = connectionUpgradedTo != nil
                self.privacyDashboardScript.setUpgradedHttps(upgradedHttps, webView: self.webView)
            })
            .store(in: &cancellables)
    }

    private func subscribeToTrackerInfo() {
        tabViewModel?.tab.$trackerInfo
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] trackerInfo in
                guard let self = self, let trackerInfo = trackerInfo, let tabUrl = self.tabViewModel?.tab.content.url else { return }
                self.privacyDashboardScript.setTrackerInfo(tabUrl, trackerInfo: trackerInfo, webView: self.webView)
            })
            .store(in: &cancellables)
    }

    private func sendProtectionStatus() {
        guard let protectionStatus = tabViewModel?.tab.protectionStatus else {
            assertionFailure("PrivacyDashboardViewController: no protectionStatus available")
            return
        }

        self.privacyDashboardScript.setProtectionStatus(protectionStatus, webView: self.webView)
    }

    private func sendLocale() {
        let locale = Locale.current.languageCode ?? "en";
        self.privacyDashboardScript.setLocale(locale, webView: self.webView)
    }

    private func sendPendingUpdates() {
        guard let domain = tabViewModel?.tab.content.url?.host else {
            assertionFailure("PrivacyDashboardViewController: no domain available")
            return
        }

        self.privacyDashboardScript.setIsPendingUpdates(pendingUpdates.values.contains(domain), webView: self.webView)
    }

    private func sendParentEntity() {
        guard let domain = tabViewModel?.tab.content.url?.host else {
            assertionFailure("PrivacyDashboardViewController: no domain available")
            return
        }

        let pageEntity = ContentBlocking.shared.trackerDataManager.trackerData.findEntity(forHost: domain)
        self.privacyDashboardScript.setParentEntity(pageEntity, webView: self.webView)
    }

    private func subscribeToServerTrust() {
        tabViewModel?.tab.$serverTrust
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .map { serverTrust in
                ServerTrustViewModel(serverTrust: serverTrust)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] serverTrustViewModel in
                guard let self = self, let serverTrustViewModel = serverTrustViewModel else { return }
                self.privacyDashboardScript.setServerTrust(serverTrustViewModel, webView: self.webView)
            })
            .store(in: &cancellables)
    }
    
    private func subscribeToConsentManaged() {
        tabViewModel?.tab.$cookieConsentManaged
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] consentManaged in
                guard let self = self else { return }
                self.privacyDashboardScript.setConsentManaged(consentManaged, webView: self.webView)
            })
            .store(in: &cancellables)
    }

}

extension PrivacyDashboardViewController: PrivacyDashboardUserScriptDelegate {

    func userScript(_ userScript: PrivacyDashboardUserScript, didChangeProtectionStateTo isProtected: Bool) {
        guard let domain = tabViewModel?.tab.content.url?.host else {
            assertionFailure("PrivacyDashboardViewController: no domain available")
            return
        }

        let configuration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig
        if isProtected && configuration.isUserUnprotected(domain: domain) {
            configuration.userEnabledProtection(forDomain: domain)
        } else {
            configuration.userDisabledProtection(forDomain: domain)
        }

        let completionToken = ContentBlocking.shared.contentBlockingManager.scheduleCompilation()
        pendingUpdates[completionToken] = domain
        sendPendingUpdates()
    }

    func userScript(_ userScript: PrivacyDashboardUserScript, didSetPermission permission: PermissionType, to state: PermissionAuthorizationState) {
        guard let domain = tabViewModel?.tab.content.url?.host else {
            assertionFailure("PrivacyDashboardViewController: no domain available")
            return
        }

        PermissionManager.shared.setPermission(state.persistedPermissionDecision, forDomain: domain, permissionType: permission)
    }

    func userScript(_ userScript: PrivacyDashboardUserScript, setPermission permission: PermissionType, paused: Bool) {
        tabViewModel?.tab.permissions.set([permission], muted: paused)
    }

    func userScript(_ userScript: PrivacyDashboardUserScript, setHeight height: Int) {
        var height = CGFloat(height)
        if height > preferredMaxHeight {
            height = preferredMaxHeight
        }
        
        if skipLayoutAnimation {
            contentHeightConstraint.constant = height
            skipLayoutAnimation = false
        } else {
            NSAnimationContext.runAnimationGroup { [weak self] context in
                context.duration = 1/3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self?.contentHeightConstraint.animator().constant = height
            }
        }
    }

    func userScript(_ userScript: PrivacyDashboardUserScript, didRequestOpenUrlInNewTab url: URL) {
        guard let tabCollection = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel
        else {
            assertionFailure("could not access shared tabCollectionViewModel")
            return
        }
        tabCollection.appendNewTab(with: .url(url), selected: true)
    }
}

extension PrivacyDashboardViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        subscribeToPermissions()
        subscribeToTrackerInfo()
        subscribeToConnectionUpgradedTo()
        subscribeToServerTrust()
        sendProtectionStatus()
        sendLocale()
        sendPendingUpdates()
        sendParentEntity()
        subscribeToConsentManaged()
    }

}
