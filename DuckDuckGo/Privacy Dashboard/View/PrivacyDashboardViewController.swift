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

final class PrivacyDashboardViewController: NSViewController {

    @IBOutlet var webView: WKWebView!
    private let privacyDashboardScript = PrivacyDashboardUserScript()
    private var cancellables = Set<AnyCancellable>()
    @Published var pendingUpdates = [String: String]()

    weak var tabViewModel: TabViewModel?
    var serverTrustViewModel: ServerTrustViewModel?

    private var contentBlockinRulesUpdatedCancellable: AnyCancellable?
    private var altContentBlockinRulesUpdatedCancellable: AnyCancellable?

    override func viewDidLoad() {
        privacyDashboardScript.delegate = self
        initWebView()
        webView.configuration.userContentController.addHandlerNoContentWorld(privacyDashboardScript)

        contentBlockinRulesUpdatedCancellable = prepareContentBlockingCancellable(publisher: ContentBlocking.contentBlockingUpdating.contentBlockingRules)
        altContentBlockinRulesUpdatedCancellable = prepareContentBlockingCancellable(publisher: ContentBlocking.altContentBlockingUpdating.contentBlockingRules)
    }

    private func prepareContentBlockingCancellable(publisher: ContentBlockingUpdating.NewRulesPublisher) -> AnyCancellable? {
        return publisher.receive(on: RunLoop.main).sink { [weak self] newRules in
            dispatchPrecondition(condition: .onQueue(.main))

            guard let self = self, let newRules = newRules, !self.pendingUpdates.isEmpty else { return }

            var didUpdate = false
            for token in newRules.completionTokens {
                if self.pendingUpdates.removeValue(forKey: token) != nil {
                    didUpdate = true
                }
            }

            if didUpdate {
                self.sendPendingUpdates()

                let activeTab = self.tabViewModel?.tab
                activeTab?.reload()
            }
        }
    }

    override func viewWillAppear() {
        let url = Bundle.main.url(forResource: "popup", withExtension: "html", subdirectory: "duckduckgo-privacy-dashboard/build/macos/html")!
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    override func viewWillDisappear() {
        cancellables.removeAll()
    }

    public func isPendingUpdates() -> Bool {
        return !pendingUpdates.isEmpty
    }

    private func initWebView() {
        let configuration = WKWebViewConfiguration()
        
#if DEBUG
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        view.addAndLayout(webView)
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

        let authState: PrivacyDashboardUserScript.AuthorizationState = PermissionType.allCases.compactMap { permissionType in
            guard let alwaysGrant = PermissionManager.shared.permission(forDomain: domain, permissionType: permissionType) else {
                if usedPermissions[permissionType] != nil {
                    return (permissionType, .ask)
                }
                return nil
            }
            return (permissionType, alwaysGrant ? .grant : .deny)
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
        guard let domain = tabViewModel?.tab.content.url?.host else {
            assertionFailure("PrivacyDashboardViewController: no domain available")
            return
        }

        let configuration = ContentBlocking.privacyConfigurationManager.privacyConfig
        let isProtected = !configuration.isUserUnprotected(domain: domain)
        self.privacyDashboardScript.setProtectionStatus(isProtected, webView: self.webView)
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

        let pageEntity = ContentBlocking.trackerDataManager.trackerData.findEntity(forHost: domain)
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

}

extension PrivacyDashboardViewController: PrivacyDashboardUserScriptDelegate {

    func userScript(_ userScript: PrivacyDashboardUserScript, didChangeProtectionStateTo isProtected: Bool) {
        guard let domain = tabViewModel?.tab.content.url?.host else {
            assertionFailure("PrivacyDashboardViewController: no domain available")
            return
        }

        let configuration = ContentBlocking.privacyConfigurationManager.privacyConfig
        if isProtected {
            configuration.userEnabledProtection(forDomain: domain)
        } else {
            configuration.userDisabledProtection(forDomain: domain)
        }

        let completionToken = ContentBlocking.contentBlockingManager.scheduleCompilation()
        let altToken = ContentBlocking.altContentBlockingManager.scheduleCompilation()
        pendingUpdates[completionToken] = domain
        pendingUpdates[altToken] = domain
        sendPendingUpdates()
    }

    func userScript(_ userScript: PrivacyDashboardUserScript, didSetPermission permission: PermissionType, to state: PermissionAuthorizationState) {
        guard let domain = tabViewModel?.tab.content.url?.host else {
            assertionFailure("PrivacyDashboardViewController: no domain available")
            return
        }
        switch state {
        case .ask:
            PermissionManager.shared.removePermission(forDomain: domain, permissionType: permission)
        case .deny, .grant:
            PermissionManager.shared.setPermission(state == .grant, forDomain: domain, permissionType: permission)
        }
    }

    func userScript(_ userScript: PrivacyDashboardUserScript, setPermission permission: PermissionType, paused: Bool) {
        tabViewModel?.tab.permissions.set(permission, muted: paused)
    }

    func userScript(_ userScript: PrivacyDashboardUserScript, setHeight height: Int) {
        self.preferredContentSize = CGSize(width: self.view.frame.width, height: CGFloat(height))
    }

}

extension PrivacyDashboardViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        subscribeToPermissions()
        subscribeToTrackerInfo()
        subscribeToConnectionUpgradedTo()
        subscribeToServerTrust()
        sendProtectionStatus()
        sendPendingUpdates()
        sendParentEntity()
    }

}
