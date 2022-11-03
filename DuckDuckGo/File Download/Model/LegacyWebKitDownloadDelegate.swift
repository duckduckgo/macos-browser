//
//  LegacyWebKitDownloadDelegate.swift
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

import Foundation
import WebKit
import Combine

final class LegacyWebKitDownloadDelegate: NSObject {

    private var navigationActions = [URL: WKNavigationAction]()
    private var navigationResponses = [URL: WKNavigationResponse]()
    private var responseCache = [NSObject: URLResponse]()

    override init() {
    }

    func registerDownloadNavigationAction(_ navigationAction: WKNavigationAction) {
        guard let url = navigationAction.request.url else {
            assertionFailure("WKNavigationAction.request.url is nil")
            return
        }
        self.navigationActions[url] = navigationAction
    }

    func registerDownloadNavigationResponse(_ navigationResponse: WKNavigationResponse) {
        guard let url = navigationResponse.response.url else {
            assertionFailure("WKNavigationResponse.request.url is nil")
            return
        }
        self.navigationResponses[url] = navigationResponse
    }

}

// https://github.com/WebKit/webkit/blob/main/Source/WebKit/UIProcess/API/Cocoa/_WKDownloadDelegate.h
private extension LegacyWebKitDownloadDelegate {

    @objc func _downloadDidStart(_ download: WebKitDownload) {
        guard let webView = download.webView, let url = download.originalRequest?.url else {
            assertionFailure("WebKitDownload webView or url is nil")
            return
        }
        guard let delegate = webView.navigationDelegate as? WKWebViewDownloadDelegate else {
            assertionFailure("webView.navigationDelegate does not conform to WKWebViewDownloadDelegate")
            return
        }

        if let navigationAction = self.navigationActions[url] {
            self.navigationActions[url] = nil
            delegate.webView(webView, navigationAction: navigationAction, didBecomeDownload: download)
        } else if let navigationResponse = self.navigationResponses[url] {
            self.navigationResponses[url] = nil
            delegate.webView(webView, navigationResponse: navigationResponse, didBecomeDownload: download)
        } else {
            delegate.webView(webView, contextMenuDidCreateDownload: download)
        }
    }

    @objc func _download(_ download: WebKitDownload, didReceiveResponse response: URLResponse) {
        self.responseCache[download.asNSObject()] = response
    }

    @objc func _download(_ download: WebKitDownload,
                         decideDestinationWithSuggestedFilename suggestedFilename: String,
                         completionHandler: @escaping (Bool, String?) -> Void) {
        defer {
            self.responseCache[download.asNSObject()] = nil
        }
        guard let delegate = download.downloadDelegate else {
            assertionFailure("_download:decideDestinationWithSuggestedFilename: delegate not set")
            completionHandler(false, nil)
            return
        }

        delegate.download(download, decideDestinationUsing: self.responseCache[download.asNSObject()], suggestedFilename: suggestedFilename) { url in
            completionHandler(false, url?.path)
        }
    }

    @objc func _downloadDidFinish(_ download: WebKitDownload) {
        download.downloadDelegate?.downloadDidFinish(download)
    }

    @objc func _downloadDidCancel(_ download: WebKitDownload) {
        download.downloadDelegate?.download(download, didFailWithError: URLError(.cancelled), resumeData: nil)
    }

    @objc func _download(_ download: WebKitDownload, didFailWithError error: Error) {
        download.downloadDelegate?.download(download, didFailWithError: error, resumeData: nil)
    }

    @objc(_download:didReceiveAuthenticationChallenge:completionHandler:)
    func _download(_ download: WebKitDownload,
                   didReceive challenge: URLAuthenticationChallenge,
                   completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        download.downloadDelegate?.download(download, didReceive: challenge, completionHandler: completionHandler)
            ?? download.webView?.navigationDelegate?.webView?(download.webView!, didReceive: challenge, completionHandler: completionHandler)
    }

    @objc(_download:didReceiveData:)
    func _download(_ download: WebKitDownload, didReceiveData length: UInt64) {
        download.downloadDelegate?.download(download, didReceiveData: length)
    }

}
