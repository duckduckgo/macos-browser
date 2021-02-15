//
//  PreserveLoginsWorker.swift
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

import Foundation
import AppKit
import Combine

enum LoginResult: Equatable {
    case authFlow(authLoginDomain: String)
    case twoFactorAuthFlow(authLoginDomain: String)
    case loginDetected(authLoginDomain: String, forwardedToDomain: String)
}

enum NavigationEvent {
    case userAction
    case pageBeganLoading(url: URL)
    case pageFinishedLoading
    case redirect(url: URL)
    case detectedLogin(url: URL)
}

class LoginDetectionService {

    /// The detected login result, provided as a string representing the host name. This can be used to present a Fireproofing prompt.
    private var loginDetectionHandler: (String) -> Void

    /// The URL detected by the Login Detection user script. This URL will represent the location where the login took place, e.g. example.com/login.
    private var detectedLoginURL: URL?

    /// The URL which was redirected to post-login, and is a candidate for Fireproofing.
    private var postLoginURL: URL?

    /// Tracks the authentication hosts throughout the login process.
    private var authDetectedHosts = [String]()

    /// Processes login detection after a short delay, to ensure that no more page redirects are coming.
    private var loginDetectionWorkItem: DispatchWorkItem?

    init(loginDetectionHandler: @escaping (String) -> Void) {
        self.loginDetectionHandler = loginDetectionHandler
    }

    func handle(navigationEvent: NavigationEvent, delayAfterFinishingPageLoad: Bool = true) {
        switch navigationEvent {
        case .userAction:
            discardLoginAttempt()

        case .pageBeganLoading(let url):
            guard let host = url.baseHost else { return }

            if !authDetectedHosts.contains(host) {
                authDetectedHosts = []
            }

            // If a login attempt is taking place, consider the new URL to be the one that should be fireproofed.
            // The login detection work item should be canceled as it'll be restarted when the page finishes loading.
            loginDetectionWorkItem?.cancel()
            if detectedLoginURL != nil {
                self.postLoginURL = url
            }

        case .pageFinishedLoading:
            if delayAfterFinishingPageLoad {
                loginDetectionWorkItem?.cancel()
                loginDetectionWorkItem = DispatchWorkItem { [weak self] in
                    self?.handleLoginDetection()
                }

                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.25, execute: loginDetectionWorkItem!)
            } else {
                loginDetectionWorkItem?.cancel()
                handleLoginDetection()
            }

        case .detectedLogin(let url):
            self.detectedLoginURL = url

        case .redirect(let url):
            handleRedirection(url: url)
        }
    }

    private func discardLoginAttempt() {
        self.postLoginURL = nil
        self.detectedLoginURL = nil
    }

    private func handleLoginDetection() {
        guard let urlToCheck = postLoginURL else {
            return
        }

        guard let result = detectLogin(url: urlToCheck) else {
            discardLoginAttempt()
            return
        }

        switch result {
        case .authFlow(authLoginDomain: let authLoginDomain):
            print("DETECT LOGIN: Got auth flow: \(authLoginDomain)")

        case .loginDetected(authLoginDomain: _, forwardedToDomain: let forwardedToDomain):
            loginDetectionHandler(forwardedToDomain)
            authDetectedHosts = []
            detectedLoginURL = nil
        default: break
        }
    }

    private func detectLogin(url: URL) -> LoginResult? {
        guard let validLoginAttempt = detectedLoginURL, let host = url.baseHost else { return nil }

        if authDetectedHosts.contains(host) {
            print("DETECT LOGIN: Got auth detected host")
            return LoginResult.authFlow(authLoginDomain: host)
        }

        if url.isOAuthURL || url.isSingleSignOnURL {
            print("DETECT LOGIN: Got SSO URL")
            return LoginResult.authFlow(authLoginDomain: host)
        }

        if url.isTwoFactorURL {
            print("DETECT LOGIN: Got 2FA URL")
            return LoginResult.twoFactorAuthFlow(authLoginDomain: host)
        }

        if domainOrPathDidChange(validLoginAttempt, url) {
            return LoginResult.loginDetected(authLoginDomain: validLoginAttempt.baseHost!, forwardedToDomain: host)
        }

        return nil
    }

    private func handleRedirection(url: URL) {
        guard let host = url.baseHost else { return }

        print("REDIRECTION: Redirected to \(url)")

        if url.isOAuthURL || url.isSingleSignOnURL || authDetectedHosts.contains(host) {
            authDetectedHosts.append(host)
            print("REDIRECTION: Got OAuth/SSO URL, added auth host: \(host)")
        }

        if detectedLoginURL != nil {
            print("REDIRECTION: Have detected login URL, adding URL to check \(url)")
            self.postLoginURL = url
        }
    }

    private func domainOrPathDidChange(_ detectedURL: URL, _ currentURL: URL) -> Bool {
        return currentURL.host != detectedURL.host || currentURL.path != detectedURL.path
    }

    // TODO: Move to the tab, or whatever should be presenting the alert
    private func promptToFireproof(_ domain: String) {
        guard let window = NSApplication.shared.keyWindow, !AppDelegate.isRunningTests else { return }

        let alert = NSAlert.fireproofAlert(with: domain)
        alert.beginSheetModal(for: window) { response in
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                FireproofDomains.shared.addToAllowed(domain: domain)
                // TODO: Load favicon?
            }
        }
    }

}

// TODO: Move to the tab, or whatever should be presenting the alert
fileprivate extension NSAlert {

    static func fireproofAlert(with domain: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.fireproofConfirmationTitle(domain: domain)
        alert.informativeText = UserText.fireproofConfirmationMessage
        alert.alertStyle = .warning
        alert.icon = NSImage(named: "BurnAlert")
        alert.addButton(withTitle: UserText.fireproof)
        alert.addButton(withTitle: UserText.notNow)
        return alert
    }

}
