//
//  ActiveSiteInfoPublisher.swift
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
final class ActiveSiteInfoPublisher {

    private var activeDomain: String? {
        didSet {
            refreshActiveSiteInfo()
        }
    }

    private let subject: CurrentValueSubject<ActiveSiteInfo?, Never>

    private let activeDomainPublisher: AnyPublisher<String?, Never>
    private let proxySettings: TransparentProxySettings
    private var cancellables = Set<AnyCancellable>()

    init(activeDomainPublisher: AnyPublisher<String?, Never>,
         proxySettings: TransparentProxySettings) {

        subject = CurrentValueSubject<ActiveSiteInfo?, Never>(nil)
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
                refreshActiveSiteInfo()
            default:
                break
            }
        }.store(in: &cancellables)
    }

    // MARK: - Refreshing

    func refreshActiveSiteInfo() {
        if activeActiveSiteInfo != subject.value {
            subject.send(activeActiveSiteInfo)
        }
    }

    // MARK: - Active Site Troubleshooting Info

    var activeActiveSiteInfo: ActiveSiteInfo? {
        guard let activeDomain else {
            return nil
        }

        return site(forDomain: activeDomain.droppingWwwPrefix())
    }

    private func site(forDomain domain: String) -> ActiveSiteInfo? {
        let icon: NSImage?
        let currentSite: NetworkProtectionUI.ActiveSiteInfo?

        icon = FaviconManager.shared.getCachedFavicon(forDomainOrAnySubdomain: domain, sizeCategory: .small)?.image
        let proxySettings = TransparentProxySettings(defaults: .netP)
        currentSite = NetworkProtectionUI.ActiveSiteInfo(
            icon: icon,
            domain: domain,
            excluded: proxySettings.isExcluding(domain: domain))

        return currentSite
    }
}

extension ActiveSiteInfoPublisher: Publisher {
    typealias Output = ActiveSiteInfo?
    typealias Failure = Never

    nonisolated
    func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, NetworkProtectionUI.ActiveSiteInfo? == S.Input {

        subject.receive(subscriber: subscriber)
    }
}
