//
//  ErrorPageTabExtension.swift
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
import WebKit
import Combine
import ContentScopeScripts

final class ErrorPageTabExtension {
    weak var webView: ErrorPageTabExtensionDelegate?
    private var cancellables = Set<AnyCancellable>()

    init(webViewPublisher: some Publisher<WKWebView, Never>) {
        webViewPublisher.sink { [weak self] webView in
            self?.webView = webView
        }.store(in: &cancellables)
    }

    @MainActor
    private func loadSSLErrorHTML(errorType: SSLErrorType, url: URL, alternate: Bool) {
        let urlString = url.toString(decodePunycode: true, dropScheme: true, dropTrailingSlash: true)
        let html = SSLErrorPageHTMLTemplate(siteURL: urlString, specificErrorMessage: errorType.message(for: urlString)).makeHTMLFromTemplate()

        webView?.loadAlternateHTML(html, baseURL: .error, forUnreachableURL: url)
        loadHTML(html: html, url: url, alternate: alternate)
    }

    @MainActor
    private func loadErrorHTML(_ error: WKError, header: String, forUnreachableURL url: URL, alternate: Bool) {
        let html = ErrorPageHTMLTemplate(error: error, header: header).makeHTMLFromTemplate()
        loadHTML(html: html, url: url, alternate: alternate)
    }

    @MainActor
    private func loadHTML(html: String, url: URL, alternate: Bool) {
        if alternate {
            webView?.loadAlternateHTML(html, baseURL: .error, forUnreachableURL: url)
        } else {
            webView?.setDocumentHtml(html)
        }
    }

    enum SSLErrorType {
        case expired
        case wrongHost
        case selfSigned
        case invalid

        func message(for url: String) -> String {
            switch self {
            case .expired:
                return "The security certificate for <b>\(url)</b> is expired."
            case .wrongHost:
                return "The security certificate for <b>\(url)</b> does not match <b>*.\(url)</b>."
            case .selfSigned:
                return "The security certificate for <b>\(url)</b> is not trusted by your computer's operating system."
            case .invalid:
                return "The security certificate for <b>\(url)</b> is not trusted by your computer's operating system."
            }
        }
    }

}

extension ErrorPageTabExtension: NavigationResponder {
    @MainActor
    func navigation(_ navigation: Navigation, didFailWith error: WKError) {
        let url = error.failingUrl ?? navigation.url
        guard navigation.isCurrent else { return }

        if !error.isFrameLoadInterrupted, !error.isNavigationCancelled {
            // when already displaying the error page and reload navigation fails again: don‘t navigate, just update page HTML
            guard let webView else { return }
            let shouldPerformAlternateNavigation = navigation.url != webView.url || navigation.navigationAction.targetFrame?.url != .error

            if error.errorCode == NSURLErrorServerCertificateUntrusted,
               let errorCode = error.userInfo["_kCFStreamErrorCodeKey"] as? Int {
                print(error.userInfo)
                var errorType: SSLErrorType = .invalid
                switch errorCode {
                case -9814:
                    errorType = .expired
                case -9843:
                    errorType = .wrongHost
                case -9807:
                    errorType = .selfSigned
                default:
                    errorType = .invalid
                }
                loadSSLErrorHTML(errorType: errorType, url: url, alternate: shouldPerformAlternateNavigation)
            } else {
                loadErrorHTML(error, header: UserText.errorPageHeader, forUnreachableURL: url, alternate: shouldPerformAlternateNavigation)
            }
        }
    }
}

protocol ErrorPageTabExtensionProtocol: AnyObject, NavigationResponder {
}

extension ErrorPageTabExtension: TabExtension, ErrorPageTabExtensionProtocol {
    typealias PublicProtocol = ErrorPageTabExtensionProtocol
    func getPublicProtocol() -> PublicProtocol { self }
}

extension TabExtensions {
    var errorPage: ErrorPageTabExtensionProtocol? {
        resolve(ErrorPageTabExtension.self)
    }
}

protocol ErrorPageTabExtensionDelegate: NSObject {
    var url: URL? { get }
    func loadAlternateHTML(_ html: String, baseURL: URL, forUnreachableURL failingURL: URL)
    func setDocumentHtml(_ html: String)
}

extension WKWebView: ErrorPageTabExtensionDelegate {}
