//
//  NetworkProtectionBundle.swift
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

import Foundation

enum NetworkProtectionBundle {
    static var identifier: String {
        extensionBundle().bundleIdentifier!
    }
    
    static func extensionBundle() -> Bundle {
#if NETWORK_EXTENSION // When this code is compiled for any network-extension
        return Bundle.main
#elseif NETP_SYSTEM_EXTENSION // When this code is compiled for the app when configured to use the sysex
        let extensionsDirectoryURL = URL(fileURLWithPath: "Contents/Library/SystemExtensions", relativeTo: Bundle.main.bundleURL)
        return extensionBundle(at: extensionsDirectoryURL)
#else // When this code is compiled for the app when configured to use the appex
        let extensionsDirectoryURL = URL(fileURLWithPath: "Contents/Plugins", relativeTo: Bundle.main.bundleURL)
        return extensionBundle(at: extensionsDirectoryURL)
#endif
    }
    
    static func extensionBundle(at url: URL) -> Bundle {
        let extensionURLs: [URL]
        do {
            extensionURLs = try FileManager.default.contentsOfDirectory(at: url,
                                                                        includingPropertiesForKeys: nil,
                                                                        options: .skipsHiddenFiles)
        } catch let error {
            fatalError("🔵 Failed to get the contents of \(url.absoluteString): \(error.localizedDescription)")
        }
        
        // - TODO: fix this to work well with other extensions
        guard let extensionURL = extensionURLs.first else {
            fatalError("🔵 Failed to find any system extensions")
        }
        
        guard let extensionBundle = Bundle(url: extensionURL) else {
            fatalError("🔵 Failed to create a bundle with URL \(extensionURL.absoluteString)")
        }
        
        return extensionBundle
    }
    
    // - TODO: should probably be relocated
    static func usesSystemKeychain() -> Bool {
#if NETP_SYSTEM_EXTENSION
        true
#else
        false
#endif
    }
}
