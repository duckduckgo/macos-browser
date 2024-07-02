//
//  PhishingErrorPageHTMLTemplate.swift
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
import Common

struct PhishingErrorPageHTMLTemplate: ErrorPageHTMLTemplating {
    let domain: String
    let tld = TLD()

    static var htmlTemplatePath: String {
        guard let file = ContentScopeScripts.Bundle.path(forResource: "index", ofType: "html", inDirectory: "pages/specialerrorpage") else {
            assertionFailure("HTML template not found")
            return ""
        }
        return file
    }

    func makeHTMLFromTemplate() -> String {
        let phishingError = PhishingError()
        guard let html = try? String(contentsOfFile: Self.htmlTemplatePath) else {
            assertionFailure("Should be able to load template")
            return ""
        }
        let eTldPlus1 = tld.eTLDplus1(domain) ?? domain
        let loadTimeData = createJSONString(header: phishingError.header, body: phishingError.body(for: domain), advancedButton: phishingError.advancedButton, leaveSiteButton: phishingError.leaveSiteButton, advancedInfoHeader: phishingError.advancedInfoTitle, specificMessage: phishingError.specificMessage(for: domain, eTldPlus1: eTldPlus1), advancedInfoBody: phishingError.advancedInfoBody, visitSiteButton: phishingError.visitSiteButton)
        return html.replacingOccurrences(of: "$LOAD_TIME_DATA$", with: loadTimeData, options: .literal)
    }

    private func createJSONString(header: String, body: String, advancedButton: String, leaveSiteButton: String, advancedInfoHeader: String, specificMessage: String, advancedInfoBody: String, visitSiteButton: String) -> String {
        let innerDictionary: [String: Any] = [
            "header": header.escapedUnicodeHtmlString(),
            "body": body.escapedUnicodeHtmlString(),
            "advancedButton": advancedButton.escapedUnicodeHtmlString(),
            "leaveSiteButton": leaveSiteButton.escapedUnicodeHtmlString(),
            "advancedInfoHeader": advancedInfoHeader.escapedUnicodeHtmlString(),
            "specificMessage": specificMessage.escapedUnicodeHtmlString(),
            "advancedInfoBody": advancedInfoBody.escapedUnicodeHtmlString(),
            "visitSiteButton": visitSiteButton.escapedUnicodeHtmlString()
        ]

        let outerDictionary: [String: Any] = [
            "strings": innerDictionary
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: outerDictionary, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            } else {
                return "Error: Could not encode jsonData to String."
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}

public struct PhishingError {

    var header: String {
        return UserText.phishingErrorPageHeader
    }

    func body(for domain: String) -> String {
        let boldDomain = "<span style=\"font-weight: 600;\">\(domain)</span>"
        return UserText.phishingErrorPageBody(boldDomain)
    }

    var advancedButton: String {
        return UserText.phishingErrorPageAdvancedButton
    }

    var leaveSiteButton: String {
        return UserText.phishingErrorPageLeaveSiteButton
    }

    var visitSiteButton: String {
        return UserText.phishingErrorPageVisitSiteButton
    }

    var advancedInfoTitle: String {
        return UserText.phishingErrorAdvancedInfoTitle
    }

    var advancedInfoBody: String {
        return UserText.phishingErrorAdvancedInfoBodyPhishing
    }

    func specificMessage(for domain: String, eTldPlus1: String) -> String {
        let boldDomain = "<span style=\"font-weight: 600;\">\(domain)</span>"
        let boldETldPlus1 = "<span style=\"font-weight: 600;\">\(eTldPlus1)</span>"
        return UserText.phishingErrorPageBody(boldDomain)
    }
}
