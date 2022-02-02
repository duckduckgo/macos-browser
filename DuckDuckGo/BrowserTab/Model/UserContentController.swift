//
//  UserContentController.swift
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

import WebKit
import Combine
import BrowserServicesKit

protocol UserContentControllerDelegate: AnyObject {
    func userContentController(_ userContentController: UserContentController, didInstallUserScripts userScripts: UserScripts)
}

final class UserContentController: WKUserContentController {
    private var blockingRulesUpdatedCancellable: AnyCancellable?
    weak var delegate: UserContentControllerDelegate?

    let privacyConfigurationManager: PrivacyConfigurationManager

    struct ContentBlockingAssets {
        let rules: [String: WKContentRuleList]
        let scripts: UserScripts
    }

    public init<Pub: Publisher>(assetsPublisher: Pub, privacyConfigurationManager: PrivacyConfigurationManager)
    where Pub.Failure == Never, Pub.Output == ContentBlockingAssets {

        self.privacyConfigurationManager = privacyConfigurationManager
        super.init()

        attachToContentBlockingAssetsPublisher(publisher: assetsPublisher)
    }

    public convenience init(privacyConfigurationManager: PrivacyConfigurationManager = ContentBlocking.shared.privacyConfigurationManager) {
        self.init(assetsPublisher: ContentBlocking.shared.contentBlockingUpdating.userContentBlockingAssets,
                  privacyConfigurationManager: privacyConfigurationManager)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var cbaInstalledContinuation: (() -> Void)?

    private(set) var uccContentBlockingAssetsInstalled = false {
        didSet {
            if uccContentBlockingAssetsInstalled {
                cbaInstalledContinuation?()
                self.cbaInstalledContinuation = nil
            }
        }
    }

    private func attachToContentBlockingAssetsPublisher<Pub: Publisher>(publisher: Pub)
    where Pub.Failure == Never, Pub.Output == ContentBlockingAssets {

        blockingRulesUpdatedCancellable = publisher.receive(on: DispatchQueue.main).sink { [weak self] assets in
            self?.installContentBlockingAssets(assets)
        }
    }

    private func installContentBlockingAssets(_ assets: ContentBlockingAssets) {
        dispatchPrecondition(condition: .onQueue(.main))

        self.contentRuleLists = assets.rules
        self.scripts = assets.scripts

        self.uccContentBlockingAssetsInstalled = true
    }

    private(set) var contentRuleLists: [String: WKContentRuleList] = [:] {
        didSet {
            self.removeAllContentRuleLists()
            if self.privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking) {
                for rulesList in contentRuleLists.values {
                    self.add(rulesList)
                }
            }
        }
    }

    struct ContentRulesNotFoundError: Error {}
    func enableContentRuleList(withIdentifier identifier: String) throws {
        guard let ruleList = self.contentRuleLists[identifier] else {
            throw ContentRulesNotFoundError()
        }
        self.add(ruleList)
    }

    func disableContentRuleList(withIdentifier identifier: String) {
        guard let ruleList = self.contentRuleLists[identifier] else {
            assertionFailure("Rule list not installed")
            return
        }
        self.remove(ruleList)
    }

    private(set) var scripts: UserScripts? {
        willSet {
            self.removeAllUserScripts()
        }
        didSet {
            guard let userScripts = scripts else { return }

            userScripts.scripts.forEach(self.addUserScript)
            userScripts.userScripts.forEach(self.addHandler)

            guard let delegate = delegate else {
                assertionFailure("UserContentController delegate not set")
                return
            }

            delegate.userContentController(self, didInstallUserScripts: userScripts)
        }
    }

    override func removeAllUserScripts() {
        super.removeAllUserScripts()
        self.scripts?.userScripts.forEach(self.removeHandler(_:))
    }

    func userContentControllerContentBlockingAssetsInstalled() async {
        guard self.privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking),
              !contentBlockingAssetsInstalled
        else { return }

        await withCheckedContinuation { c in
            self.cbaInstalledContinuation = { [continuation=self.cbaInstalledContinuation] in
                c.resume()
                continuation?()
            }
        } as Void
    }

}

extension WKUserContentController {

    var contentBlockingAssetsInstalled: Bool {
        guard let self = self as? UserContentController else {
            assertionFailure("unexpected WKUserContentController")
            return true
        }
        return self.uccContentBlockingAssetsInstalled
    }

    func awaitContentBlockingAssetsInstalled() async {
        guard let self = self as? UserContentController else {
            assertionFailure("unexpected WKUserContentController")
            return
        }
        await self.userContentControllerContentBlockingAssetsInstalled()
    }

}
