//
//  SiteTroubleshootingInfoPublisher.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Combine
import Foundation
import NetworkProtectionProxy
import NetworkProtectionUI

@MainActor
final class SiteTroubleshootingInfoPublisher {

    private var activeDomain: String? {
        didSet {
            refreshSiteTroubleshootingInfo()
        }
    }

    private let subject: CurrentValueSubject<SiteTroubleshootingInfo?, Never>

    private let activeDomainPublisher: AnyPublisher<String?, Never>
    private let proxySettings: TransparentProxySettings
    private var cancellables = Set<AnyCancellable>()

    init(activeDomainPublisher: AnyPublisher<String?, Never>,
         proxySettings: TransparentProxySettings) {

        subject = CurrentValueSubject<SiteTroubleshootingInfo?, Never>(nil)
        self.activeDomainPublisher = activeDomainPublisher
        self.proxySettings = proxySettings

        subscribeToActiveDomainChanges()
        subscribeToExclusionChanges()
    }

    private func subscribeToActiveDomainChanges() {
        activeDomainPublisher
            .assign(to: \.activeDomain, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private func subscribeToExclusionChanges() {
        proxySettings.changePublisher.sink { [weak self] change in
            guard let self else { return }

            switch change {
            case .excludedDomains:
                refreshSiteTroubleshootingInfo()
            default:
                break
            }
        }.store(in: &cancellables)
    }

    // MARK: - Refreshing

    func refreshSiteTroubleshootingInfo() {
        if activeSiteTroubleshootingInfo != subject.value {
            subject.send(activeSiteTroubleshootingInfo)
        }
    }

    // MARK: - Active Site Troubleshooting Info

    var activeSiteTroubleshootingInfo: SiteTroubleshootingInfo? {
        guard let activeDomain else {
            return nil
        }

        return site(forDomain: activeDomain.droppingWwwPrefix())
    }

    private func site(forDomain domain: String) -> SiteTroubleshootingInfo? {
        let icon: NSImage?
        let currentSite: NetworkProtectionUI.SiteTroubleshootingInfo?

        icon = FaviconManager.shared.getCachedFavicon(for: domain, sizeCategory: .small)?.image
        let proxySettings = TransparentProxySettings(defaults: .netP)
        currentSite = NetworkProtectionUI.SiteTroubleshootingInfo(
            icon: icon,
            domain: domain,
            excluded: proxySettings.isExcluding(domain: domain))

        return currentSite
    }
}

extension SiteTroubleshootingInfoPublisher: Publisher {
    typealias Output = SiteTroubleshootingInfo?
    typealias Failure = Never

    nonisolated
    func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, NetworkProtectionUI.SiteTroubleshootingInfo? == S.Input {

        subject.receive(subscriber: subscriber)
    }
}
