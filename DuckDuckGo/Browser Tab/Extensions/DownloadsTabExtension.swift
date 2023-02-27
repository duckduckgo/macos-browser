//
//  DownloadsTabExtension.swift
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

import Combine
import Common
import Foundation
import Navigation
import WebKit

protocol TabDownloadsDelegate: AnyObject {
    func fileIconFlyAnimationOriginalRect(for downloadTask: WebKitDownloadTask) -> NSRect?
}

final class DownloadsTabExtension: NSObject {

    private let downloadManager: FileDownloadManagerProtocol
    private let isChildTab: Bool

    @Published
    private var savePanelDialogRequest: SavePanelDialogRequest? {
        didSet {
            savePanelDialogRequest?.addCompletionHandler { [weak self, weak savePanelDialogRequest] _ in
                if let self,
                    let savePanelDialogRequest,
                    self.savePanelDialogRequest === savePanelDialogRequest {

                    self.savePanelDialogRequest = nil
                }
            }
        }
    }

    weak var delegate: TabDownloadsDelegate?

    init(downloadManager: FileDownloadManagerProtocol, isChildTab: Bool) {
        self.downloadManager = downloadManager
        self.isChildTab = isChildTab
        super.init()
    }

    func saveWebViewContentAs(_ webView: WKWebView) {
        webView.getMimeType { [weak webView, weak self] mimeType in
            guard let self, let webView else { return }
            guard case .some(.html) = mimeType.flatMap(UTType.init(mimeType:)) else {
                if let url = webView.url {
                    webView.startDownload(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)) { download in
                        self.downloadManager.add(download, delegate: self, location: .prompt)
                    }
                }
                return
            }

            let parameters = SavePanelParameters(suggestedFilename: webView.suggestedFilename, fileTypes: [.html, .webArchive, .pdf])
            self.savePanelDialogRequest = SavePanelDialogRequest(parameters) { result in
                guard let (url, fileType) = try? result.get() else { return }
                webView.exportWebContent(to: url, as: fileType.flatMap(WKWebView.ContentExportType.init) ?? .html)
            }
        }
    }

}

extension DownloadsTabExtension: NavigationResponder {

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        if navigationAction.shouldDownload
            // to be modularized later, modifiers should be collected on click (and key down!) event and passed as .custom NavigationType
            || (navigationAction.navigationType.isLinkActivated && NSApp.isOptionPressed && !NSApp.isCommandPressed) {

            return .download
        }

        return .next
    }

    @MainActor
    func decidePolicy(for navigationResponse: NavigationResponse) async -> NavigationResponsePolicy? {
        guard navigationResponse.httpResponse?.isSuccessful == true,
              !navigationResponse.canShowMIMEType || navigationResponse.shouldDownload
        else {
            return .next
        }
        // prevent download twice for session restoration/tab reopening requests
        guard !navigationResponse.isForMainFrame || navigationResponse.mainFrameNavigation?.request.cachePolicy != .returnCacheDataElseLoad else {
            return .cancel
        }

        return .download
    }

    @MainActor
    func navigationAction(_ navigationAction: NavigationAction, willBecomeDownloadIn webView: WKWebView) {
#if !APPSTORE
        // register the navigationResponse for legacy _WKDownload to be called back on the Tab
        // further download will be passed to webView:navigationResponse:didBecomeDownload:
        webView.configuration.processPool
            .setDownloadDelegateIfNeeded(using: LegacyWebKitDownloadDelegate.init)?
            .registerDownloadDidStartCallback(for: navigationAction.url) { [weak self] download in
                self?.navigationAction(navigationAction, didBecome: download) ?? { download.cancel() }()
            }
#endif
    }

    @MainActor
    func navigationAction(_ navigationAction: NavigationAction, didBecome download: WebKitDownload) {
        enqueueDownload(download, withNavigationAction: navigationAction)
    }

    @MainActor
    func navigationResponse(_ navigationResponse: NavigationResponse, willBecomeDownloadIn webView: WKWebView) {
#if !APPSTORE
        // register the navigationResponse for legacy _WKDownload to be called back on the Tab
        // further download will be passed to webView:navigationResponse:didBecomeDownload:
        webView.configuration.processPool
            .setDownloadDelegateIfNeeded(using: LegacyWebKitDownloadDelegate.init)?
            .registerDownloadDidStartCallback(for: navigationResponse.url) { [weak self] download in
                self?.navigationResponse(navigationResponse, didBecome: download) ?? { download.cancel() }()
            }
#endif
    }

    @MainActor
    func navigationResponse(_ navigationResponse: NavigationResponse, didBecome download: WebKitDownload) {
        enqueueDownload(download, withNavigationAction: navigationResponse.mainFrameNavigation?.navigationAction)
    }

    func enqueueDownload(_ download: WebKitDownload, withNavigationAction navigationAction: NavigationAction?) {
        let task = downloadManager.add(download, delegate: self, location: .auto)

        // If the download has started from a popup Tab - close it after starting the download
        // e.g. download button on this page:
        // https://en.wikipedia.org/wiki/Guitar#/media/File:GuitareClassique5.png
        guard isChildTab,
              let webView = download.webView,
              // webView has no navigation history (downloaded navigationAction has started from an empty state)
              (navigationAction?.redirectHistory?.first ?? navigationAction)?.fromHistoryItemIdentity == nil
        else { return }

        self.closeWebView(webView, afterDownloadTaskHasStarted: task)
    }

    private func closeWebView(_ webView: WKWebView, afterDownloadTaskHasStarted downloadTask: WebKitDownloadTask) {
        // close the initiating Tab after location has been chosen and leave it open when the task was cancelled
        // the wait is needed because closing the tab would cancel download location chooser dialog
        var cancellable: AnyCancellable?
        cancellable = downloadTask.didChooseDownloadLocationPublisher.sink { completion in
            // close the tab if completed without an error (location chosen)
            if case .finished = completion {
                webView.close()
            }
            cancellable?.cancel()
        } receiveValue: { _ in }
    }

}

extension DownloadsTabExtension: WKNavigationDelegate {

    @objc(_webView:contextMenuDidCreateDownload:)
    func webView(_ webView: WKWebView, contextMenuDidCreate download: WebKitDownload) {
        // to do: url should be cleaned up before launching download
        downloadManager.add(download, delegate: self, location: .prompt)
    }

}

extension DownloadsTabExtension: DownloadTaskDelegate {

    func chooseDestination(suggestedFilename: String?, directoryURL: URL?, fileTypes: [UTType], callback: @escaping (URL?, UTType?) -> Void) {
        savePanelDialogRequest = SavePanelDialogRequest(SavePanelParameters(suggestedFilename: suggestedFilename, fileTypes: fileTypes)) { [weak self] result in
            self?.savePanelDialogRequest = nil
            guard case let .success(.some( (url: url, fileType: fileType) )) = result else {
                callback(nil, nil)
                return
            }
            callback(url, fileType)
        }
    }

    func fileIconFlyAnimationOriginalRect(for downloadTask: WebKitDownloadTask) -> NSRect? {
        self.delegate?.fileIconFlyAnimationOriginalRect(for: downloadTask)
    }

}

protocol DownloadsTabExtensionProtocol: AnyObject, NavigationResponder, DownloadTaskDelegate {
    var delegate: TabDownloadsDelegate? { get set }
    var savePanelDialogPublisher: AnyPublisher<Tab.UserDialog?, Never> { get }

    func saveWebViewContentAs(_ webView: WKWebView)
}

extension DownloadsTabExtension: TabExtension, DownloadsTabExtensionProtocol {
    func getPublicProtocol() -> DownloadsTabExtensionProtocol { self }

    var savePanelDialogPublisher: AnyPublisher<Tab.UserDialog?, Never> {
        $savePanelDialogRequest.map { $0.map { request in
            Tab.UserDialog(sender: .user, dialog: .savePanel(request))
        }}.eraseToAnyPublisher()
    }
}

extension TabExtensions {
    var downloads: DownloadsTabExtensionProtocol? {
        resolve(DownloadsTabExtension.self)
    }
}

extension Tab {

    func saveWebContentAs() {
        self.downloads?.saveWebViewContentAs(webView)
    }

}
