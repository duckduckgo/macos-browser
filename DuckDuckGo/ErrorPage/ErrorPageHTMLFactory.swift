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

import BrowserServicesKit
import ContentScopeScripts
import Foundation
import MaliciousSiteProtection
import Navigation
import SpecialErrorPages

enum ErrorPageHTMLFactory {

    static func html(for error: WKError, featureFlagger: FeatureFlagger, header: String? = nil) -> String {
        switch error as NSError {
        case is MaliciousSiteError:
            return SpecialErrorPageHTMLTemplate.htmlFromTemplate

        case is URLError where error.isServerCertificateUntrusted && featureFlagger.isFeatureOn(.sslCertificatesBypass):
            return SpecialErrorPageHTMLTemplate.htmlFromTemplate

        default:
            return ErrorPageHTMLTemplate(error: WKError(_nsError: error as NSError),
                                         header: header ?? UserText.errorPageHeader).makeHTMLFromTemplate()
        }
    }

}
