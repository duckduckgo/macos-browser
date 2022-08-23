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
    let privacyConfigurationManager: PrivacyConfigurationManager
    weak var delegate: UserContentControllerDelegate?

    struct ContentBlockingAssets {
        let contentRuleLists: [String: WKContentRuleList]
        let userScripts: UserScripts
        let completionTokens: [ContentBlockerRulesManager.CompletionToken]
    }
    @Published private(set) var contentBlockingAssets: ContentBlockingAssets? {
        willSet {
            self.removeAllContentRuleLists()
            self.removeAllUserScripts()
        }
        didSet {
            guard let contentBlockingAssets = contentBlockingAssets else { return }
            self.installContentRuleLists(contentBlockingAssets.contentRuleLists)
            self.installUserScripts(contentBlockingAssets.userScripts)
        }
    }

    private var cancellable: AnyCancellable?

    public init<Pub: Publisher>(assetsPublisher: Pub, privacyConfigurationManager: PrivacyConfigurationManager)
    where Pub.Failure == Never, Pub.Output == ContentBlockingAssets {

        self.privacyConfigurationManager = privacyConfigurationManager
        var scriptsEnabledForTab = true;
        super.init()

        cancellable = assetsPublisher.receive(on: DispatchQueue.main).map { $0 }.assign(to: \.contentBlockingAssets, onWeaklyHeld: self)

        NotificationCenter.default.addObserver(forName: .ToggleUserScripts, object: nil, queue: .main) {[weak self] _ in
            scriptsEnabledForTab = !scriptsEnabledForTab;
            if (scriptsEnabledForTab) {
                guard let contentBlockingAssets = self?.contentBlockingAssets else { return }
                self?.installContentRuleLists(contentBlockingAssets.contentRuleLists)
                self?.installUserScripts(contentBlockingAssets.userScripts)
                print("✅ user scripts back on")
            } else {
                print("❌ removed all user scripts")
                self?.removeAllUserScripts();
            }
        }

#if DEBUG
        // make sure delegate for UserScripts is set shortly after init
        DispatchQueue.main.async { [weak self] in
            assert(self == nil || self?.delegate != nil, "UserContentController delegate not set")
        }
#endif
    }

    public convenience init(privacyConfigurationManager: PrivacyConfigurationManager = ContentBlocking.shared.privacyConfigurationManager) {
        self.init(assetsPublisher: ContentBlocking.shared.contentBlockingUpdating.userContentBlockingAssets,
                  privacyConfigurationManager: privacyConfigurationManager)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func installContentRuleLists(_ contentRuleLists: [String: WKContentRuleList]) {
        guard self.privacyConfigurationManager.privacyConfig.isEnabled(featureKey: .contentBlocking) else { return }

        contentRuleLists.values.forEach(self.add)
    }

    struct ContentRulesNotFoundError: Error {}
    func enableContentRuleList(withIdentifier identifier: String) throws {
        guard let ruleList = self.contentBlockingAssets?.contentRuleLists[identifier] else {
            throw ContentRulesNotFoundError()
        }
        self.add(ruleList)
    }

    func disableContentRuleList(withIdentifier identifier: String) {
        guard let ruleList = self.contentBlockingAssets?.contentRuleLists[identifier] else {
            assertionFailure("Rule list not installed")
            return
        }
        self.remove(ruleList)
    }

    private func installUserScripts(_ userScripts: UserScripts) {
        userScripts.scripts.forEach(self.addUserScript)
        userScripts.userScripts.forEach(self.addHandler)

        delegate?.userContentController(self, didInstallUserScripts: userScripts)
    }

    override func removeAllUserScripts() {
        super.removeAllUserScripts()
        self.contentBlockingAssets?.userScripts.userScripts.forEach(self.removeHandler)
    }

}

extension UserContentController {

    var contentBlockingAssetsInstalled: Bool {
        contentBlockingAssets != nil
    }

    @MainActor
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

#if DEBUG || REVIEW
extension NSNotification.Name {
    public static let ToggleUserScripts = NSNotification.Name("ToggleUserScripts")
}
#endif
