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
import os

enum NavigationEvent {
    case userAction
    case pageBeganLoading(url: URL)
    case pageFinishedLoading
    case redirect(url: URL)
    case detectedLogin(url: URL)
}

class LoginDetectionService {

    private enum LoginResult: Equatable {
        case authenticationFlow(authenticationDomain: String)
        case twoFactorAuthFlow(authenticationDomain: String)
        case loginDetected(authenticationDomain: String, forwardedDomain: String)
    }

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
            os_log("Received user action, discard login attempt", log: .fire)
            discardLoginAttempt()

        case .pageBeganLoading(let url):

            // If a login attempt is taking place, consider the new URL to be the one that should be fireproofed.
            // The login detection work item should be canceled as it'll be restarted when the page finishes loading.
            loginDetectionWorkItem?.cancel()
            if detectedLoginURL != nil {
                self.postLoginURL = url
            }

        case .pageFinishedLoading:

            // By default the login detection logic will wait a bit before checking whether to display the Fireproof prompt.
            // This gives the browser a chance to stop being redirected by auth providers, but it can be bypassed by providing false for
            // `delayAfterFinishingPageLoad`, which is useful during unit tests.
            if delayAfterFinishingPageLoad {
                loginDetectionWorkItem?.cancel()
                loginDetectionWorkItem = DispatchWorkItem { [weak self] in
                    self?.handleLoginDetection()
                }

                os_log("Queueing login detection job", log: .fire)
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.25, execute: loginDetectionWorkItem!)
            } else {
                loginDetectionWorkItem?.cancel()
                handleLoginDetection()
            }

        case .detectedLogin(let url):
            os_log("Setting detected login URL: %s", log: .fire, url.absoluteString)
            self.detectedLoginURL = url

        case .redirect(let url):
            handleRedirection(url: url)
        }
    }

    private func discardLoginAttempt() {
        loginDetectionWorkItem?.cancel()
        loginDetectionWorkItem = nil
        postLoginURL = nil
        detectedLoginURL = nil
        authDetectedHosts = []

        os_log("Discarded login attempt", log: .fire)
    }

    private func handleLoginDetection() {
        os_log("Login detection work item fired", log: .fire)

        guard let urlToCheck = postLoginURL else {
            os_log("Login detection work item has no URL to detect logins for, discarding attempt", log: .fire)
            return
        }

        guard let result = detectLogin(url: urlToCheck) else {
            os_log("Login detection couldn't detect login, discarding attempt", log: .fire)
            discardLoginAttempt()
            return
        }

        switch result {
        case .authenticationFlow(let authLoginDomain):
            authDetectedHosts.append(authLoginDomain)

        case .loginDetected(_, let forwardedToDomain):
            loginDetectionHandler(forwardedToDomain)
            authDetectedHosts = []
            detectedLoginURL = nil

        default: break
        }
    }

    private func detectLogin(url: URL) -> LoginResult? {
        guard let validLoginAttempt = detectedLoginURL, let host = url.host else {
            os_log("Login detection hit guard statement", log: .fire)
            return nil
        }

        if authDetectedHosts.contains(host) {
            os_log("Login detection returning auth flow", log: .fire)
            return LoginResult.authenticationFlow(authenticationDomain: host)
        }

        if url.isOAuthURL || url.isSingleSignOnURL {
            os_log("Login detection returning OAuth/SSO auth flow", log: .fire)
            return LoginResult.authenticationFlow(authenticationDomain: host)
        }

        if url.isTwoFactorURL {
            os_log("Login detection returning 2FA flow", log: .fire)
            return LoginResult.twoFactorAuthFlow(authenticationDomain: host)
        }

        if domainOrPathDidChange(validLoginAttempt, url) {
            os_log("Detected login to %{public}s (auth domain %{public}s)", log: .fire, host, validLoginAttempt.host!)
            return LoginResult.loginDetected(authenticationDomain: validLoginAttempt.host!, forwardedDomain: host)
        } else {
            os_log("DID NOT detect login to %{public}s (auth domain %{public}s)", log: .fire, host, validLoginAttempt.host!)
        }

        return nil
    }

    private func handleRedirection(url: URL) {
        guard let host = url.host else { return }

        if url.isOAuthURL || url.isSingleSignOnURL {
            os_log("Redirection added authentication host %{public}s", log: .fire, host)
            authDetectedHosts.append(host)
        }

        if detectedLoginURL != nil {
            self.postLoginURL = url
        }
    }

    private func domainOrPathDidChange(_ detectedURL: URL, _ currentURL: URL) -> Bool {
        return currentURL.host != detectedURL.host || currentURL.path != detectedURL.path
    }

}
