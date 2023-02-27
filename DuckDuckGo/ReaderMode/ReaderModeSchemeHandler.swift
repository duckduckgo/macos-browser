//
//  ReaderModeSchemeHandler.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Common
import Foundation
import WebKit

extension URL {
    static let readerUrl = URL(string: "\(ReaderModeSchemeHandler.readerModeScheme)://reader")!
}

final class ReaderModeSchemeHandler: NSObject, WKURLSchemeHandler {
    static let readerModeScheme = "reader"
    static private let readerCss = "Reader.css"
    static private let readerHtml = "Reader.html"

    var style = ReaderModeStyle.default

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let url = urlSchemeTask.request.url!
        let cssUrl = Bundle(for: Self.self).url(forResource: Self.readerCss, withExtension: nil)!

        if url.path == Self.readerCss {
            let data = (try? Data(contentsOf: cssUrl))!

            urlSchemeTask.didReceive(URLResponse(url: url, mimeType: "text/css", expectedContentLength: data.count, textEncodingName: nil))
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()

            return
        }

        guard url.host == URL.readerUrl.host,
              let readabilityURL = url.getParameter(named: "url").flatMap({ URL(string: $0.removingPercentEncoding!) })
        else {
            urlSchemeTask.didFailWithError(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL))
            return
        }
        guard let readabilityResult = try? ReaderModeCache.shared.readabilityResult(for: readabilityURL) else {
            urlSchemeTask.didFailWithError(CocoaError(.fileReadNoSuchFile))
            return
        }

        let css = (try? String(contentsOf: cssUrl, encoding: .utf8))!
        let tmplURL = Bundle(for: Self.self).url(forResource: Self.readerHtml, withExtension: nil)!
        let tmpl = (try? NSMutableString(contentsOf: tmplURL, encoding: String.Encoding.utf8.rawValue))!

        tmpl.replaceOccurrences(of: "%READER-CSS%", with: css, options: .literal, range: NSRange(location: 0, length: tmpl.length))
        tmpl.replaceOccurrences(of: "%READER-STYLE%", with: style.encode(), options: .literal, range: NSRange(location: 0, length: tmpl.length))
        tmpl.replaceOccurrences(of: "%READER-DOMAIN%", with: simplifyDomain(readabilityResult.domain), options: .literal, range: NSRange(location: 0, length: tmpl.length))
        tmpl.replaceOccurrences(of: "%READER-URL%", with: readabilityResult.url, options: .literal, range: NSRange(location: 0, length: tmpl.length))
        tmpl.replaceOccurrences(of: "%READER-TITLE%", with: readabilityResult.title, options: .literal, range: NSRange(location: 0, length: tmpl.length))
        tmpl.replaceOccurrences(of: "%READER-CREDITS%", with: readabilityResult.credits, options: .literal, range: NSRange(location: 0, length: tmpl.length))
        tmpl.replaceOccurrences(of: "%READER-CONTENT%", with: readabilityResult.content, options: .literal, range: NSRange(location: 0, length: tmpl.length))
        let data = tmpl.data(using: NSUTF8StringEncoding)!

        urlSchemeTask.didReceive(URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: nil))
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    static let DomainPrefixesToSimplify = ["www.", "mobile.", "m.", "blog."]
    private func simplifyDomain(_ domain: String) -> String {
        return Self.DomainPrefixesToSimplify.first { domain.hasPrefix($0) }.map {
            String($0[$0.index($0.startIndex, offsetBy: $0.count)...])
        } ?? domain
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

}
