//
//  PrivacyReferenceTestHelper.swift
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
import BrowserServicesKit

struct PrivacyReferenceTestHelper {
    static let privacyReferenceTestPlatformName = "macos-browser"

    enum FileError: Error {
        case unknownFile
        case invalidFileContents
    }
    
    func data(for path: String, in bundle: Bundle) throws -> Data {
        let url = bundle.resourceURL!.appendingPathComponent(path)
        let path = url.path
        return try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
    }
    
    func decodeResource<T: Decodable>(_ path: String, from bundle: Bundle) -> T {
        do {
            let data = try data(for: path, in: bundle)
            let jsonResult = try JSONDecoder().decode(T.self, from: data)
            return jsonResult
            
        } catch {
            fatalError("Can't decode \(path) - Error \(error.localizedDescription)")
        }
    }
    
    func privacyConfiguration(withConfigPath path: String, bundle: Bundle) -> PrivacyConfiguration {
        guard let configData = try? data(for: path, in: bundle) else {
            fatalError("Can't decode \(path)")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: configData, options: []) as? [String: Any] else {
            fatalError("Can't decode \(path)")
        }
        
        let domain = MockDomainsProtectionStore()
        let configurationData = PrivacyConfigurationData(json: json)
        return AppPrivacyConfiguration(data: configurationData, identifier: UUID().uuidString, localProtection: domain)
    }
}
