//
//  ReleaseNotesTabExtension.swift
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
import Navigation
import Combine
import Common

#if SPARKLE

protocol ReleaseNotesUserScriptProvider {

    var releaseNotesUserScript: ReleaseNotesUserScript? { get }

}

extension UserScripts: ReleaseNotesUserScriptProvider {}

public struct ReleaseNotesValues: Codable {

    let status: String
    let currentVersion: String
    let latestVersion: String?
    let lastUpdate: UInt
    let releaseTitle: String?
    let releaseNotes: [String]?
    let releaseNotesPrivacyPro: [String]?

}

final class ReleaseNotesTabExtension: NavigationResponder {

    private var cancellables = Set<AnyCancellable>()
    private weak var webView: WKWebView? {
        didSet {
            releaseNotesUserScript?.webView = webView
        }
    }
    private weak var releaseNotesUserScript: ReleaseNotesUserScript?

    init(scriptsPublisher: some Publisher<some ReleaseNotesUserScriptProvider, Never>,
         webViewPublisher: some Publisher<WKWebView, Never>) {

        webViewPublisher.sink { [weak self] webView in
            self?.webView = webView
        }.store(in: &cancellables)

        scriptsPublisher.sink { [weak self] scripts in
            self?.releaseNotesUserScript = scripts.releaseNotesUserScript
            self?.releaseNotesUserScript?.webView = self?.webView

            DispatchQueue.main.async { [weak self] in
                self?.setUpScript(for: self?.webView?.url)
            }
        }.store(in: &cancellables)
    }

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        if navigationAction.url.isReleaseNotesScheme {
            return .allow
        }
        return .next
    }

    @MainActor
    private func setUpScript(for url: URL?) {
        guard NSApp.runType != .uiTests else {
            return
        }
        let updateController = Application.appDelegate.updateController!
        Publishers.CombineLatest(updateController.isUpdateBeingLoadedPublisher, updateController.latestUpdatePublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.releaseNotesUserScript?.onUpdate()
            }
            .store(in: &cancellables)
    }

}

protocol ReleaseNotesTabExtensionProtocol: AnyObject, NavigationResponder {}

extension ReleaseNotesTabExtension: ReleaseNotesTabExtensionProtocol, TabExtension {
    func getPublicProtocol() -> ReleaseNotesTabExtensionProtocol { self }
}

extension TabExtensions {
    var releaseNotes: ReleaseNotesTabExtensionProtocol? { resolve(ReleaseNotesTabExtension.self) }
}

extension ReleaseNotesValues {

    init(status: String,
         currentVersion: String,
         lastUpdate: UInt) {
        self.init(status: status,
                  currentVersion: currentVersion,
                  latestVersion: nil,
                  lastUpdate: lastUpdate,
                  releaseTitle: nil,
                  releaseNotes: nil,
                  releaseNotesPrivacyPro: nil)
    }

    init(from updateController: UpdateController?) {
        let currentVersion = "\(AppVersion().versionNumber) (\(AppVersion().buildNumber))"
        let lastUpdate = UInt((updateController?.lastUpdateCheckDate ?? Date()).timeIntervalSince1970)
        let status: String
        let latestVersion: String

        guard let updateController, !updateController.isUpdateBeingLoaded else {
            self.init(status: "loading",
                      currentVersion: currentVersion,
                      lastUpdate: lastUpdate)
            return
        }

        if let latestUpdate = updateController.latestUpdate {
            status = latestUpdate.isInstalled ? "loaded" : "updateReady"
            latestVersion = "\(latestUpdate.version) (\(latestUpdate.build))"
            self.init(status: status,
                      currentVersion: currentVersion,
                      latestVersion: latestVersion,
                      lastUpdate: lastUpdate,
                      releaseTitle: latestUpdate.title,
                      releaseNotes: latestUpdate.releaseNotes,
                      releaseNotesPrivacyPro: latestUpdate.releaseNotesPrivacyPro)
            return
        } else {
            self.init(status: "loaded",
                      currentVersion: currentVersion,
                      lastUpdate: lastUpdate)
        }
    }

}

#else

protocol ReleaseNotesTabExtensionProtocol: AnyObject, NavigationResponder {}

extension ReleaseNotesTabExtension: ReleaseNotesTabExtensionProtocol, TabExtension {
    func getPublicProtocol() -> ReleaseNotesTabExtensionProtocol { self }
}

extension TabExtensions {
    var releaseNotes: ReleaseNotesTabExtensionProtocol? { resolve(ReleaseNotesTabExtension.self) }
}

final class ReleaseNotesTabExtension: NavigationResponder {
}

#endif
