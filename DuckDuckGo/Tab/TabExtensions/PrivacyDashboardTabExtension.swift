//
//  PrivacyDashboardTabExtension.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import BrowserServicesKit
import Combine
import Common
import ContentBlocking
import Foundation
import Navigation
import PrivacyDashboard
import PhishingDetection

final class PrivacyDashboardTabExtension {

    private let contentBlocking: any ContentBlockingProtocol
    private let certificateTrustEvaluator: CertificateTrustEvaluating
    private var phishingStateManager: PhishingStateManager

    @Published private(set) var privacyInfo: PrivacyInfo?

    private(set) var isCertificateValid: Bool?

    private var previousPrivacyInfosByURL: [String: PrivacyInfo] = [:]

    private var cancellables = Set<AnyCancellable>()

    init(contentBlocking: some ContentBlockingProtocol,
         certificateTrustEvaluator: CertificateTrustEvaluating,
         autoconsentUserScriptPublisher: some Publisher<UserScriptWithAutoconsent?, Never>,
         didUpgradeToHttpsPublisher: some Publisher<URL, Never>,
         trackersPublisher: some Publisher<DetectedTracker, Never>,
         webViewPublisher: some Publisher<WKWebView, Never>,
         phishingStateManager: PhishingStateManager) {

        self.contentBlocking = contentBlocking
        self.certificateTrustEvaluator = certificateTrustEvaluator
        self.phishingStateManager = phishingStateManager

        autoconsentUserScriptPublisher.sink { [weak self] autoconsentUserScript in
            autoconsentUserScript?.delegate = self
        }.store(in: &cancellables)

        didUpgradeToHttpsPublisher.sink { [weak self] upgradedUrl in
            self?.setMainFrameConnectionUpgradedTo(upgradedUrl)
        }.store(in: &cancellables)

        trackersPublisher.sink { [weak self] tracker in
            guard let self, let url = URL(string: tracker.request.pageUrl) else { return }

            switch tracker.type {
            case .tracker:
                self.privacyInfo?.trackerInfo.addDetectedTracker(tracker.request, onPageWithURL: url)
            case .thirdPartyRequest:
                self.privacyInfo?.trackerInfo.add(detectedThirdPartyRequest: tracker.request)
            case .trackerWithSurrogate(host: let host):
                self.privacyInfo?.trackerInfo.addInstalledSurrogateHost(host, for: tracker.request, onPageWithURL: url)
                self.privacyInfo?.trackerInfo.addDetectedTracker(tracker.request, onPageWithURL: url)
            }
        }.store(in: &cancellables)

        webViewPublisher.map {
            $0.publisher(for: \.serverTrust)
        }
        .switchToLatest()
        .sink { [weak self] serverTrust in
            Task { [weak self] in
                await self?.updatePrivacyInfo(with: serverTrust)
            }
        }
        .store(in: &cancellables)

        webViewPublisher
            .flatMap { $0.publisher(for: \.url) }
            .sink { [weak self] url in
                Task { [weak self] in
                    await self?.updatePrivacyInfo(with: url)
                }
            }
            .store(in: &cancellables)

    }

    private func updatePrivacyInfo(with trust: SecTrust?) async {
        let isValid = await self.certificateTrustEvaluator.evaluateCertificateTrust(trust: trust)
        await MainActor.run {
            self.isCertificateValid = isValid
            if isValid ?? false {
                self.privacyInfo?.serverTrust = trust
            } else {
                self.privacyInfo?.serverTrust = nil
            }
        }
    }

    private func updatePrivacyInfo(with url: URL?) async {
        guard let url = url else { return }
        // Avoid hitting the API if the URL is not valid (i.e. user typing)
        guard url.isValid else { return }
        guard !(url.isDuckURLScheme || url.isDuckDuckGo) else { return }
        let malicious = phishingStateManager.tabIsPhishing
        self.phishingStateManager.setIsPhishing(malicious)
        await MainActor.run {
            self.privacyInfo?.isPhishing = malicious
        }
    }

}

extension PrivacyDashboardTabExtension {

    private func resetDashboardInfo(for url: URL, didGoBackForward: Bool) {
        guard url.isHypertextURL else {
            privacyInfo = nil
            return
        }

        if didGoBackForward, let previousPrivacyInfo = previousPrivacyInfosByURL[url.absoluteString] {
            privacyInfo = previousPrivacyInfo
        } else {
            privacyInfo = makePrivacyInfo(url: url)
        }
    }

    private func makePrivacyInfo(url: URL) -> PrivacyInfo? {
        guard let host = url.host else { return nil }

        let entity = contentBlocking.trackerDataManager.trackerData.findEntity(forHost: host)

        privacyInfo = PrivacyInfo(url: url,
                                  parentEntity: entity,
                                  protectionStatus: makeProtectionStatus(for: host),
                                  isPhishing: self.phishingStateManager.tabIsPhishing)

        previousPrivacyInfosByURL[url.absoluteString] = privacyInfo

        return privacyInfo
    }

    private func resetConnectionUpgradedTo(navigationAction: NavigationAction) {
        let isOnUpgradedPage = navigationAction.url == privacyInfo?.connectionUpgradedTo
        if navigationAction.isForMainFrame && !isOnUpgradedPage {
            privacyInfo?.connectionUpgradedTo = nil
        }
    }

    public func setMainFrameConnectionUpgradedTo(_ upgradedUrl: URL?) {
        guard let upgradedUrl else { return }
        privacyInfo?.connectionUpgradedTo = upgradedUrl
    }

    private func makeProtectionStatus(for host: String) -> ProtectionStatus {
        let config = contentBlocking.privacyConfigurationManager.privacyConfig

        let isTempUnprotected = config.isTempUnprotected(domain: host)
        let isAllowlisted = config.isUserUnprotected(domain: host)

        var enabledFeatures: [String] = []

        if !config.isInExceptionList(domain: host, forFeature: .contentBlocking) {
            enabledFeatures.append(PrivacyFeature.contentBlocking.rawValue)
        }

        return ProtectionStatus(unprotectedTemporary: isTempUnprotected,
                                enabledFeatures: enabledFeatures,
                                allowlisted: isAllowlisted,
                                denylisted: false)
    }

}

extension PrivacyDashboardTabExtension: NavigationResponder {

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        resetConnectionUpgradedTo(navigationAction: navigationAction)
        let url = navigationAction.url
        print("[+] decidePolicy for \(url) in PrivacyDashboard")
        let malicious = phishingStateManager.tabIsPhishing
        self.phishingStateManager.setIsPhishing(malicious)
        await MainActor.run {
            self.privacyInfo?.isPhishing = malicious
        }
        return .next
    }

    @MainActor
    func didCommit(_ navigation: Navigation) {
        resetDashboardInfo(for: navigation.url, didGoBackForward: navigation.navigationAction.navigationType.isBackForward)
    }

    func navigationDidFinish(_ navigation: Navigation) {
        if privacyInfo?.url != navigation.url {
            resetDashboardInfo(for: navigation.url, didGoBackForward: navigation.navigationAction.navigationType.isBackForward)
        }
    }

}

extension PrivacyDashboardTabExtension: AutoconsentUserScriptDelegate {

    func autoconsentUserScript(consentStatus: CookieConsentInfo) {
        self.privacyInfo?.cookieConsentManaged = consentStatus
    }

}

protocol PrivacyDashboardProtocol: AnyObject, NavigationResponder {
    var privacyInfo: PrivacyInfo? { get }
    var privacyInfoPublisher: AnyPublisher<PrivacyInfo?, Never> { get }
    var isCertificateValid: Bool? { get }

    func setMainFrameConnectionUpgradedTo(_ upgradedUrl: URL?)
}
extension PrivacyDashboardTabExtension: PrivacyDashboardProtocol, TabExtension {
    typealias PublicProtocol = PrivacyDashboardProtocol
    func getPublicProtocol() -> PublicProtocol { self }

    var privacyInfoPublisher: AnyPublisher<PrivacyDashboard.PrivacyInfo?, Never> {
        self.$privacyInfo.eraseToAnyPublisher()
    }

}

extension Tab {

    var privacyInfo: PrivacyInfo? {
        self.privacyDashboard?.privacyInfo
    }

    var privacyInfoPublisher: AnyPublisher<PrivacyInfo?, Never> {
        self.privacyDashboard?.privacyInfoPublisher ?? Just(nil).eraseToAnyPublisher()
    }

    func setMainFrameConnectionUpgradedTo(_ upgradedUrl: URL?) {
        self.privacyDashboard?.setMainFrameConnectionUpgradedTo(upgradedUrl)
    }

    var isCertificateValid: Bool? {
        self.privacyDashboard?.isCertificateValid
    }

}

extension TabExtensions {
    var privacyDashboard: PrivacyDashboardProtocol? {
        resolve(PrivacyDashboardTabExtension.self)
    }
}
