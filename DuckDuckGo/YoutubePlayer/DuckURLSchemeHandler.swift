//
//  DuckURLSchemeHandler.swift
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

import Foundation
import WebKit
import PhishingDetection
import ContentScopeScripts

final class DuckURLSchemeHandler: NSObject, WKURLSchemeHandler {

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = webView.url ?? urlSchemeTask.request.url else {
            assertionFailure("No URL for Duck scheme handler")
            return
        }

        switch requestURL.type {
        case .onboarding:
            handleOnboarding(urlSchemeTask: urlSchemeTask)
        case .duckPlayer:
            handleDuckPlayer(requestURL: requestURL, urlSchemeTask: urlSchemeTask, webView: webView)
        default:
            handleNativeUIPages(requestURL: requestURL, urlSchemeTask: urlSchemeTask)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

// MARK: - Native UI Paged
extension DuckURLSchemeHandler {
    static let emptyHtml = """
    <html>
      <head>
        <style>
          body {
            background: rgb(255, 255, 255);
            display: flex;
            height: 100vh;
          }
          // avoid page blinking in dark mode
          @media (prefers-color-scheme: dark) {
            body {
              background: rgb(51, 51, 51);
            }
          }
        </style>
      </head>
      <body />
    </html>
    """

    private func handleNativeUIPages(requestURL: URL, urlSchemeTask: WKURLSchemeTask) {
        // return empty page for native UI pages navigations (like the Home page or Settings) if the request is not for the Duck Player
        let data = Self.emptyHtml.utf8data

        let response = URLResponse(url: requestURL,
                                   mimeType: "text/html",
                                   expectedContentLength: data.count,
                                   textEncodingName: nil)

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
}

// MARK: - DuckPlayer
private extension DuckURLSchemeHandler {
    func handleDuckPlayer(requestURL: URL, urlSchemeTask: WKURLSchemeTask, webView: WKWebView) {
        let youtubeHandler = YoutubePlayerNavigationHandler()
        let html = youtubeHandler.makeHTMLFromTemplate()

        if #available(macOS 12.0, *) {
            let newRequest = youtubeHandler.makeDuckPlayerRequest(from: URLRequest(url: requestURL))
            webView.loadSimulatedRequest(newRequest, responseHTML: html)
        } else {
            let data = html.utf8data

            let response = URLResponse(url: requestURL,
                                       mimeType: "text/html",
                                       expectedContentLength: data.count,
                                       textEncodingName: nil)

            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        }
        PixelExperiment.fireOnboardingDuckplayerUsed5to7Pixel()
    }
}

// MARK: - Onboarding
private extension DuckURLSchemeHandler {
    func handleOnboarding(urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url else {
            assertionFailure("No URL for Onboarding scheme handler")
            return
        }
        guard let (response, data) = onboardingResponse(for: requestURL) else { return }
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func onboardingResponse(for url: URL) -> (URLResponse, Data)? {
        var fileName = "index"
        var fileExtension = "html"
        var directoryURL = URL(fileURLWithPath: "/pages/onboarding")
        directoryURL.appendPathComponent(url.path)

        if !directoryURL.pathExtension.isEmpty {
            fileExtension = directoryURL.pathExtension
            directoryURL.deletePathExtension()
            fileName = directoryURL.lastPathComponent
            directoryURL.deleteLastPathComponent()
        }

        guard let file = ContentScopeScripts.Bundle.path(forResource: fileName, ofType: fileExtension, inDirectory: directoryURL.path) else {
            assertionFailure("\(fileExtension) template not found")
            return nil
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: file)) else {
            return nil
        }
        let response = URLResponse(url: url, mimeType: mimeType(for: fileExtension), expectedContentLength: data.count, textEncodingName: nil)
        return (response, data)
    }

    func mimeType(for fileExtension: String) -> String? {
        switch fileExtension {
        case "html": return "text/html"
        case "css": return "text/css"
        case "js": return "text/javascript"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "ico": return "image/x-icon"
        case "riv": return "application/octet-stream"
        default: return nil
        }
    }

}

private extension DuckURLSchemeHandler {
    func handleErrorPage(urlSchemeTask: WKURLSchemeTask, error: Error) {
        guard let isPhishingErrorPage = requestURL.isPhishingErrorPage else { return }
        guard let urlString = requestURL.getParameter(named: "url"), let url = URL(string: urlString) else { return }
        
        let error = PhishingDetectionError.detected
        let nsError = NSError(domain: PhishingDetectionError.errorDomain, code: error.errorCode, userInfo: [
            NSURLErrorFailingURLErrorKey: url,
            NSLocalizedDescriptionKey: error.errorUserInfo[NSLocalizedDescriptionKey] ?? "Phishing detected"
        ])
        urlSchemeTask.didFailWithError(nsError)
        return
    }
}

extension URL {
    enum URLType {
        case onboarding
        case duckPlayer
    }

    var type: URLType? {
        if self.isDuckPlayer {
            return .duckPlayer
        } else if self.isOnboarding {
            return .onboarding
        } else  {
            return nil
        }
    }

    var isOnboarding: Bool {
        return isDuckURLScheme && host == "onboarding"
    }

    var isDuckURLScheme: Bool {
        navigationalScheme == .duck
    }
}
