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

import BrowserServicesKit
import Combine
import WebKit

protocol UserContentControllerDelegate: AnyObject {
    func userContentController(_ userContentController: UserContentController, didInstallUserScripts userScripts: UserScripts)
}

final class UserContentController: WKUserContentController {
    let privacyConfigurationManager: PrivacyConfigurationManager
    weak var delegate: UserContentControllerDelegate?

    struct ContentBlockingAssets {
        let contentRuleLists: [String: WKContentRuleList]
        let userScripts: UserScripts
        let completionTokens: [ContentBlockerRulesManager.CompletionToken]
    }

    @Published private(set) var contentBlockingAssets: ContentBlockingAssets? {
        willSet {
            removeAllContentRuleLists()
            removeAllUserScripts()
        }
        didSet {
            guard let contentBlockingAssets = contentBlockingAssets else { return }
            installContentRuleLists(contentBlockingAssets.contentRuleLists)
            installUserScripts(contentBlockingAssets.userScripts)
        }
    }

    private var cancellable: AnyCancellable?

    public init<Pub: Publisher>(assetsPublisher: Pub, privacyConfigurationManager: PrivacyConfigurationManager)
        where Pub.Failure == Never, Pub.Output == ContentBlockingAssets {

        self.privacyConfigurationManager = privacyConfigurationManager
        super.init()

        cancellable = assetsPublisher.receive(on: DispatchQueue.main).map { $0 }.assign(to: \.contentBlockingAssets, onWeaklyHeld: self)

        #if DEBUG
        // make sure delegate for UserScripts is set shortly after init
        DispatchQueue.main.async { [weak self] in
            assert(self == nil || self?.delegate != nil, "UserContentController delegate not set")
        }
        #endif
    }

    public convenience init(privacyConfigurationManager: PrivacyConfigurationManager = ContentBlocking.shared.privacyConfigurationManager) {
        self.init(
            assetsPublisher: ContentBlocking.shared.contentBlockingUpdating.userContentBlockingAssets,
            privacyConfigurationManager: privacyConfigurationManager)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func installContentRuleLists(_ contentRuleLists: [String: WKContentRuleList]) {
        guard privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking) else { return }

        contentRuleLists.values.forEach(add)
    }

    struct ContentRulesNotFoundError: Error {}
    func enableContentRuleList(withIdentifier identifier: String) throws {
        guard let ruleList = contentBlockingAssets?.contentRuleLists[identifier] else {
            throw ContentRulesNotFoundError()
        }
        add(ruleList)
    }

    func disableContentRuleList(withIdentifier identifier: String) {
        guard let ruleList = contentBlockingAssets?.contentRuleLists[identifier] else {
            assertionFailure("Rule list not installed")
            return
        }
        remove(ruleList)
    }

    private func installUserScripts(_ userScripts: UserScripts) {
        userScripts.scripts.forEach(addUserScript)
        userScripts.userScripts.forEach(addHandler)

        delegate?.userContentController(self, didInstallUserScripts: userScripts)
    }

    override func removeAllUserScripts() {
        super.removeAllUserScripts()
        contentBlockingAssets?.userScripts.userScripts.forEach(removeHandler)
    }

}

extension UserContentController {

    var contentBlockingAssetsInstalled: Bool {
        contentBlockingAssets != nil
    }

    func awaitContentBlockingAssetsInstalled() async {
        guard !contentBlockingAssetsInstalled else { return }

        await withCheckedContinuation { c in
            var cancellable: AnyCancellable!
            cancellable = $contentBlockingAssets.receive(on: DispatchQueue.main).sink { assets in
                guard assets != nil else { return }
                withExtendedLifetime(cancellable) {
                    c.resume()
                    cancellable.cancel()
                }
            }
        } as Void
    }

}
