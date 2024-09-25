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
import os.log
import UniformTypeIdentifiers
import WebKit

protocol TabDownloadsDelegate: AnyObject {
    func fileIconFlyAnimationOriginalRect(for downloadTask: WebKitDownloadTask) -> NSRect?
}

final class DownloadsTabExtension: NSObject {

    private let downloadManager: FileDownloadManagerProtocol
    private let downloadsPreferences: DownloadsPreferences
    private let isBurner: Bool
    private var isRestoringSessionState = false

    enum DownloadLocation {
        case auto
        case prompt
        case temporary
    }
    private var nextSaveDataRequestDownloadLocation: DownloadLocation = .auto

    @Published
    private(set) var savePanelDialogRequest: SavePanelDialogRequest? {
        willSet {
            newValue?.addCompletionHandler { [weak self, weak savePanelDialogRequest=newValue] _ in
                if let self,
                    let savePanelDialogRequest,
                    self.savePanelDialogRequest === savePanelDialogRequest {

                    self.savePanelDialogRequest = nil
                }
            }
        }
    }

    weak var delegate: TabDownloadsDelegate?

    init(downloadManager: FileDownloadManagerProtocol, isBurner: Bool, downloadsPreferences: DownloadsPreferences = .shared) {
        self.downloadManager = downloadManager
        self.isBurner = isBurner
        self.downloadsPreferences = downloadsPreferences
        super.init()
    }

    func saveWebViewContent(from webView: WKWebView, pdfHUD: WKPDFHUDViewWrapper?, location: DownloadLocation) {
        Task { @MainActor in
            await saveWebViewContent(from: webView, pdfHUD: pdfHUD, location: location)
        }
    }

    @MainActor
    private func saveWebViewContent(from webView: WKWebView, pdfHUD: WKPDFHUDViewWrapper?, location: DownloadLocation) async {
        let mimeType = pdfHUD != nil ? UTType.pdf.preferredMIMEType : await webView.mimeType
        switch mimeType {
        case UTType.html.preferredMIMEType:
            assert([.prompt, .auto].contains(location))

            let parameters = SavePanelParameters(suggestedFilename: webView.suggestedFilename, fileTypes: [.html, .webArchive, .pdf])
            self.savePanelDialogRequest = SavePanelDialogRequest(parameters) { result in
                guard let (url, fileType) = try? result.get() else { return }
                webView.exportWebContent(to: url, as: fileType.flatMap(WKWebView.ContentExportType.init) ?? .html)
            }

        case UTType.pdf.preferredMIMEType:
            self.nextSaveDataRequestDownloadLocation = location
            let success = webView.savePDF(pdfHUD) // calls `saveDownloadedData(_:suggestedFilename:mimeType:originatingURL)`
            guard success else { fallthrough }

        default:
            guard let url = webView.url else {
                assertionFailure("Can‘t save web content without URL loaded")
                return
            }
            if url.isFileURL {
                self.nextSaveDataRequestDownloadLocation = location
                do {
                    _=try await self.saveDownloadedData(nil, suggestedFilename: url.lastPathComponent, mimeType: mimeType ?? "text/html", originatingURL: url)
                } catch {
                    assertionFailure("Save web content failed with \(error)")
                }
                return
            }

            let destination = self.downloadDestination(for: location, suggestedFilename: webView.suggestedFilename ?? "")
            let download = await webView.startDownload(using: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad))

            self.downloadManager.add(download, fireWindowSession: FireWindowSessionRef(window: webView.window), delegate: self, destination: destination)
        }

    }

    private func downloadDestination(for location: DownloadLocation, suggestedFilename: String) -> WebKitDownloadTask.DownloadDestination {
        switch location {
        case .auto:
            return .auto
        case .prompt:
            return .prompt
        case .temporary:
            let suggestedFilename = suggestedFilename.isEmpty ? UUID().uuidString : suggestedFilename
            let fm = FileManager.default
            let dirURL = fm.temporaryDirectory.appendingPathComponent(.uniqueFilename())
            try? fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
            return .preset(dirURL.appendingPathComponent(suggestedFilename))
        }
    }

    private func saveDownloadedData(_ data: Data?, to toURL: URL, originatingURL: URL) throws {
        let fm = FileManager.default

        // if no data provided - copy file from local url to the destination url
        guard let data else {
            guard originatingURL.isFileURL else {
                assertionFailure("No data provided for non-file URL")
                return
            }
            try Progress.withPublishedProgress(url: toURL) {
                try fm.copyItem(at: originatingURL, to: toURL, incrementingIndexIfExists: true)
            }
            return
        }

        let tempURL = fm.temporaryDirectory.appendingPathComponent(.uniqueFilename())
        // First save file in a temporary directory
        try data.write(to: tempURL)
        // Then move the file to the download location and show a bounce if the file is in a location on the user's dock.
        try Progress.withPublishedProgress(url: toURL) {
            try fm.moveItem(at: tempURL, to: toURL, incrementingIndexIfExists: true)
        }
    }

}

extension DownloadsTabExtension: NavigationResponder {

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {
        if case .sessionRestoration = navigationAction.navigationType {
            self.isRestoringSessionState = true
        } else if isRestoringSessionState,
                  navigationAction.isUserInitiated || navigationAction.isCustom || navigationAction.isUserEnteredUrl
                    || [.reload, .formSubmitted, .formResubmitted, .alternateHtmlLoad, .reload].contains(navigationAction.navigationType)
                    || navigationAction.navigationType.isBackForward {
            self.isRestoringSessionState = false
        }

        if (navigationAction.shouldDownload && !self.isRestoringSessionState)
            // to be modularized later, modifiers should be collected on click (and key down!) event and passed as .custom NavigationType
            || (navigationAction.navigationType.isLinkActivated && NSApp.isOptionPressed && !NSApp.isCommandPressed) {

            return .download
        }

        return .next
    }

    @MainActor
    func decidePolicy(for navigationResponse: NavigationResponse) async -> NavigationResponsePolicy? {
        // get an initial Navigation Action
        let firstNavigationAction = navigationResponse.mainFrameNavigation?.redirectHistory.first
            ?? navigationResponse.mainFrameNavigation?.navigationAction

        guard navigationResponse.httpResponse?.isSuccessful != false, // download non-http responses
              !navigationResponse.url.isDirectory, // don‘t download a local directory
              !responseCanShowMIMEType(navigationResponse) || navigationResponse.shouldDownload
                // if user pressed Opt+Enter in the Address bar to download from a URL
                || (navigationResponse.mainFrameNavigation?.redirectHistory.last ?? navigationResponse.mainFrameNavigation?.navigationAction)?.navigationType == .custom(.userRequestedPageDownload)
        else {
            return .next // proceed with normal page loading
        }

        // prevent download twice for session restoration/tab reopening requests
        guard firstNavigationAction?.request.cachePolicy != .returnCacheDataElseLoad,
              !isRestoringSessionState
        else {
            return .cancel
        }

        return .download
    }

    private func responseCanShowMIMEType(_ response: NavigationResponse) -> Bool {
        if response.canShowMIMEType {
            return true
        } else if response.url.isFileURL {
            return Bundle.main.fileTypeExtensions.contains(response.url.pathExtension)
        }
        return false
    }

    @MainActor
    func navigationAction(_ navigationAction: NavigationAction, didBecome download: WebKitDownload) {
        enqueueDownload(download, withNavigationAction: navigationAction)
    }

    @MainActor
    func navigationResponse(_ navigationResponse: NavigationResponse, didBecome download: WebKitDownload) {
        enqueueDownload(download, withNavigationAction: navigationResponse.mainFrameNavigation?.navigationAction)
    }

    @MainActor
    func enqueueDownload(_ download: WebKitDownload, withNavigationAction navigationAction: NavigationAction?) {
        let task = downloadManager.add(download, fireWindowSession: FireWindowSessionRef(window: download.webView?.window), delegate: self, destination: .auto)
        guard let webView = download.webView else { return }

        var shouldCloseTabOnDownloadStart: Bool {
            guard let navigationAction else {
                // if converted from navigation response but no navigation was committed
                return webView.backForwardList.currentItem == nil
            }
            // get the first navigation action in the redirect series
            let initialNavigationAction = navigationAction.redirectHistory?.first ?? navigationAction
            if initialNavigationAction.isForMainFrame,
               initialNavigationAction.isTargetingNewWindow || navigationAction.isTargetingNewWindow || initialNavigationAction.navigationType == .custom(.appOpenUrl),
               // download is started in a new tab with no navigation history (downloaded navigationAction has started from an empty state)
               initialNavigationAction.fromHistoryItemIdentity == nil {
                return true
            }

            return false
        }

        // If the download has started from a popup Tab - close it after starting the download
        // e.g. download button on this page:
        // https://en.wikipedia.org/wiki/Guitar#/media/File:GuitareClassique5.png
        guard shouldCloseTabOnDownloadStart else { return }

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

    @MainActor
    @objc(_webView:contextMenuDidCreateDownload:)
    func webView(_ webView: WKWebView, contextMenuDidCreate download: WebKitDownload) {
        // to do: url should be cleaned up before launching download
        downloadManager.add(download, fireWindowSession: FireWindowSessionRef(window: webView.window), delegate: self, destination: .prompt)
    }

}

extension DownloadsTabExtension: DownloadTaskDelegate {

    @MainActor
    func chooseDestination(suggestedFilename: String?, fileTypes: [UTType], callback: @escaping @MainActor (URL?, UTType?) -> Void) {
        savePanelDialogRequest = SavePanelDialogRequest(SavePanelParameters(suggestedFilename: suggestedFilename, fileTypes: fileTypes)) { result in
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

    func saveWebViewContent(from webView: WKWebView, pdfHUD: WKPDFHUDViewWrapper?, location: DownloadsTabExtension.DownloadLocation)

    func saveDownloadedData(_ data: Data?, suggestedFilename: String, mimeType: String, originatingURL: URL) async throws -> URL?
}

extension DownloadsTabExtension: TabExtension, DownloadsTabExtensionProtocol {
    func getPublicProtocol() -> DownloadsTabExtensionProtocol { self }

    var savePanelDialogPublisher: AnyPublisher<Tab.UserDialog?, Never> {
        $savePanelDialogRequest.map { $0.map { request in
            Tab.UserDialog(sender: .user, dialog: .savePanel(request))
        }}.eraseToAnyPublisher()
    }

    @MainActor
    func saveDownloadedData(_ data: Data?, suggestedFilename: String, mimeType: String, originatingURL: URL) async throws -> URL? {
        defer {
            self.nextSaveDataRequestDownloadLocation = .auto
        }
        switch downloadDestination(for: nextSaveDataRequestDownloadLocation, suggestedFilename: suggestedFilename) {
        case .auto:
            guard !downloadsPreferences.alwaysRequestDownloadLocation,
                  let location = downloadsPreferences.effectiveDownloadLocation else { fallthrough /* prompt */ }

            let url = location.appendingPathComponent(suggestedFilename)
            try saveDownloadedData(data, to: url, originatingURL: originatingURL)
            return url

        case .prompt:
            let fileTypes = UTType(mimeType: mimeType).map { [$0] } ?? []
            let url: URL? = await withCheckedContinuation { continuation in
                chooseDestination(suggestedFilename: suggestedFilename, fileTypes: fileTypes) { url, _ in
                    continuation.resume(returning: url)
                }
            }

            guard let url else { return nil }

            try saveDownloadedData(data, to: url, originatingURL: originatingURL)
            return url

        case .preset(let destinationURL):
            try saveDownloadedData(data, to: destinationURL, originatingURL: originatingURL)
            return destinationURL

        case .resume:
            fatalError("Unexpected resume download location")
        }
    }
}

extension TabExtensions {
    var downloads: DownloadsTabExtensionProtocol? {
        resolve(DownloadsTabExtension.self)
    }
}

extension Tab {

    func saveWebContent(pdfHUD: WKPDFHUDViewWrapper?, location: DownloadsTabExtension.DownloadLocation) {
        self.downloads?.saveWebViewContent(from: webView, pdfHUD: pdfHUD, location: location)
    }

    func saveDownloadedData(_ data: Data, suggestedFilename: String, mimeType: String, originatingURL: URL) async throws -> URL? {
        try await self.downloads?.saveDownloadedData(data, suggestedFilename: suggestedFilename, mimeType: mimeType, originatingURL: originatingURL)
    }

}
