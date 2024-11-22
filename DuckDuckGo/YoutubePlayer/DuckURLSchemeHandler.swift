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

import BrowserServicesKit
import ContentScopeScripts
import FeatureFlags
import Foundation
import MaliciousSiteProtection
import WebKit

final class DuckURLSchemeHandler: NSObject, WKURLSchemeHandler {

    let featureFlagger: FeatureFlagger
    let faviconManager: FaviconManagement

    init(featureFlagger: FeatureFlagger, faviconManager: FaviconManagement = FaviconManager.shared) {
        self.featureFlagger = featureFlagger
        self.faviconManager = faviconManager
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = webView.url ?? urlSchemeTask.request.url else {
            assertionFailure("No URL for Duck scheme handler")
            return
        }

        switch requestURL.type {
        case .onboarding, .releaseNotes:
            handleSpecialPages(urlSchemeTask: urlSchemeTask)
        case .duckPlayer:
            handleDuckPlayer(requestURL: requestURL, urlSchemeTask: urlSchemeTask, webView: webView)
        case .error:
            handleErrorPage(urlSchemeTask: urlSchemeTask)
        case .newTab:
            if featureFlagger.isFeatureOn(.htmlNewTabPage) {
                if urlSchemeTask.request.url?.type == .favicon {
                    handleFavicon(urlSchemeTask: urlSchemeTask)
                } else {
                    handleSpecialPages(urlSchemeTask: urlSchemeTask)
                }
            } else {
                handleNativeUIPages(requestURL: requestURL, urlSchemeTask: urlSchemeTask)
            }
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

// MARK: - Favicons

private extension DuckURLSchemeHandler {
    /**
     * This handler supports special Duck favicon URLs and uses `FaviconManager`
     * to return a favicon in response, based on the actual favicon URL that's
     * encoded in the URL path.
     *
     * If favicon is not found, an `HTTP 404` response is returned.
     */
    func handleFavicon(urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url else {
            assertionFailure("No URL for Favicon scheme handler")
            return
        }

        /**
         * Favicon URL has the format of `duck://favicon/<url_percent_encoded_favicon_url>`.
         * Calling `requestURL.path` drops leading `duck://favicon` and automatically
         * handles percent-encoding. We only need to drop the leading forward slash to get the favicon URL.
         */
        guard let faviconURL = requestURL.path.dropping(prefix: "/").url else {
            assertionFailure("Favicon URL malformed \(requestURL.path.dropping(prefix: "/"))")
            return
        }

        guard let (response, data) = response(for: requestURL, withFaviconURL: faviconURL) else { return }
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func response(for requestURL: URL, withFaviconURL faviconURL: URL) -> (URLResponse, Data)? {
        guard faviconManager.areFaviconsLoaded,
              let favicon = faviconManager.getCachedFavicon(for: faviconURL, sizeCategory: .medium),
              let imagePNGData = favicon.image?.pngData
        else {
            guard let response = HTTPURLResponse(url: requestURL, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil) else {
                return nil
            }
            return (response, Data())
        }
        let response = URLResponse(url: requestURL, mimeType: "image/png", expectedContentLength: imagePNGData.count, textEncodingName: nil)
        return (response, imagePNGData)
    }
}

// MARK: - Onboarding & Release Notes
private extension DuckURLSchemeHandler {
    func handleSpecialPages(urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url else {
            assertionFailure("No URL for Special Pages scheme handler")
            return
        }
        guard let (response, data) = response(for: requestURL) else { return }
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func response(for url: URL) -> (URLResponse, Data)? {
        var fileName = "index"
        var fileExtension = "html"
        var directoryURL: URL
        if url.isOnboarding {
            directoryURL = URL(fileURLWithPath: "/pages/onboarding")
        } else if url.isReleaseNotesScheme {
            directoryURL = URL(fileURLWithPath: "/pages/release-notes")
        } else if url.isNewTabPage {
            directoryURL = URL(fileURLWithPath: "/pages/new-tab")
        } else {
            assertionFailure("Unknown scheme")
            return nil
        }
        directoryURL.appendPathComponent(url.path)

        if !directoryURL.pathExtension.isEmpty {
            fileExtension = directoryURL.pathExtension
            directoryURL.deletePathExtension()
            fileName = directoryURL.lastPathComponent
            directoryURL.deleteLastPathComponent()
        }

        guard let file = ContentScopeScripts.Bundle.path(forResource: fileName, ofType: fileExtension, inDirectory: directoryURL.path) else {
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, Data())
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

// MARK: Error Page
private extension DuckURLSchemeHandler {
    func handleErrorPage(urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url else {
            assertionFailure("No URL for error page scheme handler")
            return
        }

        guard requestURL.isErrorPage,
              let threat = requestURL.getParameter(named: "reason").flatMap(MaliciousSiteProtection.ThreatKind.init),
              let base64urlString = requestURL.getParameter(named: "url"),
              let decodedData = URLTokenValidator.base64URLDecode(base64URLString: base64urlString),
              let decodedString = String(data: decodedData, encoding: .utf8),
              let url = URL(string: decodedString),
              let token = requestURL.getParameter(named: "token"),
              URLTokenValidator.shared.validateToken(token, for: url) else {

            urlSchemeTask.didFailWithError(URLError(.badURL, userInfo: [NSURLErrorFailingURLErrorKey: requestURL]))
            return
        }

        let error = MaliciousSiteError(threat: threat, failingUrl: url)
        urlSchemeTask.didFailWithError(error)
    }
}

extension URL {
    enum URLType {
        case newTab
        case favicon
        case onboarding
        case duckPlayer
        case releaseNotes
        case error
    }

    var type: URLType? {
        if self.isDuckPlayer {
            return .duckPlayer
        } else if self.isOnboarding {
            return .onboarding
        } else if self.isErrorPage {
            return .error
        } else if self.isReleaseNotesScheme {
            return .releaseNotes
        } else if self.isNewTabPage {
            return .newTab
        } else if self.isFavicon {
            return .favicon
        } else {
            return nil
        }
    }

    var isOnboarding: Bool {
        return isDuckURLScheme && host == "onboarding"
    }

    var isNewTabPage: Bool {
        return isDuckURLScheme && host == "newtab"
    }

    var isFavicon: Bool {
        return isDuckURLScheme && host == "favicon"
    }

    var isDuckURLScheme: Bool {
        navigationalScheme == .duck
    }

    var isReleaseNotesScheme: Bool {
        return isDuckURLScheme && host == "release-notes"
    }

    var isErrorPage: Bool {
        isDuckURLScheme && self.host == "error"
    }

}
