//
//  ErrorPageHTMLFactory.swift
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
import PhishingDetection

protocol ErrorPageHTMLTemplating {
    static var htmlTemplatePath: String { get }
    func makeHTMLFromTemplate() -> String
}

final class ErrorPageHTMLFactory {
    static func makeTemplate(for error: Error, url: URL, errorCode: Int? = nil, header: String? = nil) -> ErrorPageHTMLTemplating? {
        let domain = url.host ?? url.absoluteString
        let defaultHeader = UserText.errorPageHeader
        let nsError = error as NSError
        let wkError = WKError(_nsError: nsError)
        switch wkError.code {
        case WKError.Code(rawValue: NSURLErrorServerCertificateUntrusted):
            return SSLErrorPageHTMLTemplate(domain: domain, errorCode: errorCode ?? 0)
        case WKError.Code(rawValue: PhishingDetectionError.detected.rawValue):
            return PhishingErrorPageHTMLTemplate()
        default:
            return ErrorPageHTMLTemplate(error: wkError, header: header ?? defaultHeader)
        }
    }
}
