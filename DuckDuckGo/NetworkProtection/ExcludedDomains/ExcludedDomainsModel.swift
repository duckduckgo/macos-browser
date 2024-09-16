//
//  ExcludedDomainsModel.swift
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

import Foundation
import NetworkProtectionProxy
import NetworkProtectionUI
import PixelKit

protocol ExcludedDomainsViewModel {
    var domains: [String] { get }

    func add(domain: String)
    func remove(domain: String)

    func askUserToReportIssues(withDomain domain: String) async
}

final class DefaultExcludedDomainsViewModel {
    let proxySettings = TransparentProxySettings(defaults: .netP)
    private let pixelKit: PixelFiring?

    init(pixelKit: PixelFiring? = PixelKit.shared) {
        self.pixelKit = pixelKit
    }
}

extension DefaultExcludedDomainsViewModel: ExcludedDomainsViewModel {
    var domains: [String] {
        proxySettings.excludedDomains
    }

    func add(domain: String) {
        guard !proxySettings.excludedDomains.contains(domain) else {
            return
        }

        proxySettings.excludedDomains.append(domain)
    }

    func remove(domain: String) {
        proxySettings.excludedDomains.removeAll { cursor in
            domain == cursor
        }
    }

    func askUserToReportIssues(withDomain domain: String) async {
        let parentWindow = await WindowControllersManager.shared.lastKeyMainWindowController?.window
        await ReportSiteIssuesPresenter(userDefaults: .netP).show(withDomain: domain, in: parentWindow)
    }
}
