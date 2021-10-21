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

final class GPCRequestFactory {
    
    struct Constants {
        static let secGPCHeader = "Sec-GPC"
    }
    
    static func requestForGPC(basedOn incomingRequest: URLRequest,
                              settings: PrivacySecurityPreferences = PrivacySecurityPreferences(),
                              config: PrivacyConfigurationManager = PrivacyConfigurationManager.shared) -> URLRequest? {
        /*
         For now, the GPC header is only applied to sites known to be honoring GPC (nytimes.com, washingtonpost.com),
         while the DOM signal is available to all websites.
         This is done to avoid an issue with back navigation when adding the header (e.g. with 't.co').
         */
        guard let url = incomingRequest.url, URL.isGPCEnabled(url: url) else { return nil }
        
        var request = incomingRequest
        // Add GPC header if needed
        if config.isEnabled(featureKey: .gpc) {
            if let headers = request.allHTTPHeaderFields,
               headers.firstIndex(where: { $0.key == Constants.secGPCHeader }) == nil {
                guard settings.gpcEnabled else { return nil }
                
                request.addValue("1", forHTTPHeaderField: Constants.secGPCHeader)
                return request
            }
        } else {
            // Check if GPC header is still there and remove it
            if let headers = request.allHTTPHeaderFields, headers.firstIndex(where: { $0.key == Constants.secGPCHeader }) != nil {
                request.setValue(nil, forHTTPHeaderField: Constants.secGPCHeader)
                return request
            }
        }
        return nil
    }
}
