//
//  OnboardingSchemeHandler.swift
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
import ContentScopeScripts
import WebKit

final class OnboardingSchemeHandler: NSObject, WKURLSchemeHandler {

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url else {
            assertionFailure("No URL for Privacy Debug Tools scheme handler")
            return
        }

        guard let (response, data) = response(for: requestURL) else { return }

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func response(for url: URL) -> (URLResponse, Data)? {
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

    private func mimeType(for fileExtension: String) -> String? {
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
