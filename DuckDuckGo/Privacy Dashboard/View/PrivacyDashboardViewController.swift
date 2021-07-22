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

final class PrivacyDashboardViewController: NSViewController {

    @IBOutlet var webView: WKWebView!
    private let privacyDashboarScript = PrivacyDashboardUserScript()
    private var cancellables = Set<AnyCancellable>()

    weak var tabViewModel: TabViewModel?
    var serverTrustViewModel: ServerTrustViewModel?

    override func viewDidLoad() {
        privacyDashboarScript.delegate = self
        initWebView()
    }

    override func viewWillAppear() {
        let url = Bundle.main.url(forResource: "popup", withExtension: "html", subdirectory: "duckduckgo-privacy-dashboard/build/macos/html")!
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    override func viewWillDisappear() {
        cancellables.removeAll()
    }

    private func initWebView() {

#if DEBUG
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: configuration)
#else
        let webView = WKWebView(frame: .zero)
#endif
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
        guard let domain = tabViewModel?.tab.url?.host else {
            privacyDashboarScript.setPermissions(Permissions(), authorizationState: [:], domain: "", in: webView)
            return
        }

        var authState = [PermissionType: PermissionAuthorizationState]()
        for permissionType in PermissionType.allCases {
            guard let alwaysGrant = PermissionManager.shared.permission(forDomain: domain, permissionType: permissionType) else {
                if usedPermissions[permissionType] != nil {
                    authState[permissionType] = .ask
                }
                continue
            }
            authState[permissionType] = alwaysGrant ? .grant : .deny
        }

        privacyDashboarScript.setPermissions(usedPermissions, authorizationState: authState, domain: domain, in: webView)
    }

    private func subscribeToTrackerInfo() {
        #warning("Inject isProtectionOn to TrackerInfoViewModel based on protectionState")

        tabViewModel?.tab.$trackerInfo
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] trackerInfo in
                guard let self = self, let trackerInfo = trackerInfo, let tabUrl = self.tabViewModel?.tab.url else { return }
                self.privacyDashboarScript.setTrackerInfo(tabUrl, trackerInfo: trackerInfo, webView: self.webView)
            })
            .store(in: &cancellables)
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
                self.privacyDashboarScript.setServerTrust(serverTrustViewModel, webView: self.webView)
            })
            .store(in: &cancellables)
    }

}

extension PrivacyDashboardViewController: PrivacyDashboardUserScriptDelegate {

    func userScript(_ userScript: PrivacyDashboardUserScript, didChangeProtectionStateTo protectionState: Bool) {
        print("didChangeProtectionState", protectionState)
    }

    func userScript(_ userScript: PrivacyDashboardUserScript, didSetPermission permission: PermissionType, to state: PermissionAuthorizationState) {
        guard let domain = tabViewModel?.tab.url?.host else {
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

}

extension PrivacyDashboardViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        subscribeToPermissions()
        subscribeToTrackerInfo()
        subscribeToServerTrust()
    }

}
