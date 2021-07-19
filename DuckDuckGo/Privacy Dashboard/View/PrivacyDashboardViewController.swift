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

    override func viewDidLoad() {
        privacyDashboarScript.delegate = self
        webView.configuration.userContentController.addUserScript(privacyDashboarScript.makeWKUserScript())
        webView.configuration.userContentController.addHandler(privacyDashboarScript)
    }

    override func viewWillAppear() {
        let url = Bundle.main.url(forResource: "privacy_dashboard", withExtension: "html")!
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    override func viewWillDisappear() {
        cancellables.removeAll()
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
        self.subscribeToPermissions()
    }

}
