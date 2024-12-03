//
//  WKWebViewMockingExtension.swift
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

import ObjectiveC
import WebKit
@testable import DuckDuckGo_Privacy_Browser

@available(macOS 12.0, *)
extension WKWebView {

    private static let simulatedRequestHandlersKey = UnsafeRawPointer(bitPattern: "simulatedRequestsKey".hashValue)!
    private static let delegateTestsProxyKey = UnsafeRawPointer(bitPattern: "delegateTestsProxyKey".hashValue)!

    // allow setting WKURLSchemeHandler for WebView-handled schemes like HTTP
    static var customHandlerSchemes = Set<URL.NavigationalScheme>() {
        didSet {
            _=swizzleHandlesURLSchemeOnce
        }
    }

    private static let swizzleHandlesURLSchemeOnce: Void = {
        let originalLoad = class_getClassMethod(WKWebView.self, #selector(WKWebView.handlesURLScheme))!
        let swizzledLoad = class_getClassMethod(WKWebView.self, #selector(WKWebView.swizzled_handlesURLScheme))!
        method_exchangeImplementations(originalLoad, swizzledLoad)
    }()

    @objc dynamic private class func swizzled_handlesURLScheme(_ urlScheme: String) -> Bool {
        guard !customHandlerSchemes.contains(URL.NavigationalScheme(rawValue: urlScheme)) else { return false }
        return self.swizzled_handlesURLScheme(urlScheme) // call original
    }

}

class TestSchemeHandler: NSObject, WKURLSchemeHandler {

    var middleware = [(URLRequest) -> WKURLSchemeTaskHandler?]()

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        for middleware in middleware {
            if let handler = middleware(urlSchemeTask.request) {
                handler(urlSchemeTask as! WKURLSchemeTaskPrivate)
                return
            }
        }
        urlSchemeTask.didFailWithError(WKError(WKError.Code(rawValue: NSURLErrorCancelled)!))
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

struct WKURLSchemeTaskHandler {

    enum OkResult {
        case data(Data, mime: String? = nil)
        case html(String)

        var mime: String? {
            switch self {
            case .data(_, mime: let mime):
                return mime
            case .html:
                return "text/html"
            }
        }
        var data: Data {
            switch self {
            case .data(let data, mime: _):
                return data
            case .html(let string):
                return string.data(using: .utf8)!
            }
        }
    }

    static func ok(code: Int = 200, headers: [String: String] = [:], _ result: OkResult) -> WKURLSchemeTaskHandler {
        .init { task in
            let response = MockHTTPURLResponse(url: task.request.url!, statusCode: code, mime: result.mime, headerFields: headers)!

            task.didReceive(response)
            task.didReceive(result.data)
            task.didFinish()
        }
    }

    static func failure(_ error: Error) -> WKURLSchemeTaskHandler {
        .init { task in
            task.didFailWithError(error)
        }
    }

    static func redirect(to url: URL) -> WKURLSchemeTaskHandler {
        redirect(to: url.absoluteString)
    }

    static func redirect(to location: String) -> WKURLSchemeTaskHandler {
        .init { task in
            let response = MockHTTPURLResponse(url: task.request.url!,
                                               statusCode: 301,
                                               mime: nil,
                                               headerFields: ["Location": location])!

            task._didPerformRedirection(response, newRequest: URLRequest(url: URL(string: location, relativeTo: task.request.url)!))
            task.didReceive(response)
            task.didFinish()
        }
    }

    static func redirect(to url: URL, with error: NSError) -> WKURLSchemeTaskHandler {
        .init { task in
            let response = MockHTTPURLResponse(url: task.request.url!,
                                               statusCode: 301,
                                               mime: nil,
                                               headerFields: ["Location": url.absoluteString])!

            task._didPerformRedirection(response, newRequest: URLRequest(url: url))
            task.didFailWithError(error)
        }
    }

    let handler: (WKURLSchemeTaskPrivate) -> Void
    init(handler: @escaping (WKURLSchemeTaskPrivate) -> Void) {
        self.handler = handler
    }

    func callAsFunction(_ task: WKURLSchemeTaskPrivate) {
        handler(task)
    }

}

class MockHTTPURLResponse: HTTPURLResponse, @unchecked Sendable {

    private let mime: String?

    override var mimeType: String? {
        mime ?? super.mimeType
    }

    override var suggestedFilename: String? {
        URLResponse(url: url!, mimeType: mimeType, expectedContentLength: Int(expectedContentLength), textEncodingName: textEncodingName).suggestedFilename ?? super.suggestedFilename
    }

    init?(url: URL, statusCode: Int, mime: String?, httpVersion: String? = nil, headerFields: [String: String]?) {
        self.mime = mime
        super.init(url: url, statusCode: statusCode, httpVersion: httpVersion, headerFields: headerFields)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
