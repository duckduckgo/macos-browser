//
//  GPCRequestFactory.swift
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
import BrowserServicesKit

final class GPCRequestFactory {
    
    static let shared = GPCRequestFactory()
    
    struct Constants {
        static let secGPCHeader = "Sec-GPC"
    }

    private let privacySecurityPreferences: PrivacySecurityPreferences

    init(privacySecurityPreferences: PrivacySecurityPreferences = PrivacySecurityPreferences.shared) {
        self.privacySecurityPreferences = privacySecurityPreferences
    }
    
    func requestForGPC(basedOn incomingRequest: URLRequest,
                       config: PrivacyConfiguration = ContentBlocking.shared.privacyConfigurationManager.privacyConfig) -> URLRequest? {
        func removingHeader(fromRequest incomingRequest: URLRequest) -> URLRequest? {
            var request = incomingRequest
            if let headers = request.allHTTPHeaderFields, headers.firstIndex(where: { $0.key == Constants.secGPCHeader }) != nil {
                request.setValue(nil, forHTTPHeaderField: Constants.secGPCHeader)
                return request
            }
            
            return nil
        }
        
        /*
         For now, the GPC header is only applied to sites known to be honoring GPC (nytimes.com, washingtonpost.com),
         while the DOM signal is available to all websites.
         This is done to avoid an issue with back navigation when adding the header (e.g. with 't.co').
         */
        guard let url = incomingRequest.url, URL.isGPCEnabled(url: url) else {
            // Remove GPC header if its still there (or nil)
            return removingHeader(fromRequest: incomingRequest)
        }
        
        // Add GPC header if needed
        if config.isFeature(.gpc, enabledForDomain: incomingRequest.url?.host) && privacySecurityPreferences.gpcEnabled {
            var request = incomingRequest
            if let headers = request.allHTTPHeaderFields,
               headers.firstIndex(where: { $0.key == Constants.secGPCHeader }) == nil {
                request.addValue("1", forHTTPHeaderField: Constants.secGPCHeader)
                return request
            }
        } else {
            // Check if GPC header is still there and remove it
            return removingHeader(fromRequest: incomingRequest)
        }
        
        return nil
    }

}
