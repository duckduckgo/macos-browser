//
//  DownloadsTabExtensionMock.swift
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
import UniformTypeIdentifiers
import protocol Navigation.WebKitDownload
@testable import DuckDuckGo_Privacy_Browser

class DownloadsTabExtensionMock: NSObject, DownloadsTabExtensionProtocol {

    private(set) var didCallSaveWebViewContent = false
    private(set) var capturedWebView: WKWebView?

    @Published
    private(set) var didCallSaveDownloadedData = false
    private(set) var capturedSavedDownloadData: Data?
    private(set) var capturedSuggestedFilename: String?
    private(set) var capturedMimeType: String?
    private(set) var capturedOriginatingURL: URL?

    var savePanelDialogSubject = PassthroughSubject<DuckDuckGo_Privacy_Browser.Tab.UserDialog?, Never>()

    var delegate: DuckDuckGo_Privacy_Browser.TabDownloadsDelegate?

    var savePanelDialogPublisher: AnyPublisher<DuckDuckGo_Privacy_Browser.Tab.UserDialog?, Never> {
        savePanelDialogSubject.eraseToAnyPublisher()
    }

    func saveWebViewContent(from webView: WKWebView, pdfHUD: WKPDFHUDViewWrapper?, location: DownloadsTabExtension.DownloadLocation) {
        didCallSaveWebViewContent = true
        capturedWebView = webView
    }

    func saveDownloadedData(_ data: Data?, suggestedFilename: String, mimeType: String, originatingURL: URL) async throws -> URL? {
        didCallSaveDownloadedData = true
        capturedSavedDownloadData = data
        capturedSuggestedFilename = suggestedFilename
        capturedMimeType = mimeType
        capturedOriginatingURL = originatingURL

        return nil
    }

    func chooseDestination(suggestedFilename: String?, fileTypes: [UTType], callback: @escaping @MainActor (URL?, UTType?) -> Void) {}

    func fileIconFlyAnimationOriginalRect(for downloadTask: DuckDuckGo_Privacy_Browser.WebKitDownloadTask) -> NSRect? { .zero }

}

// MARK: - TabExtension

extension DownloadsTabExtensionMock: TabExtension {

    func getPublicProtocol() -> DownloadsTabExtensionProtocol { self }

    @objc(_webView:contextMenuDidCreateDownload:)
    func webView(_ webView: WKWebView, contextMenuDidCreate download: WebKitDownload) {}

}
