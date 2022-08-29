//
//  DarkReaderFixesManager.swift
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

struct DarkReaderFix: Codable {
    let url: [String]
    let invert: [String]
    let css: String
    let ignoreInlineStyle: [String]
    let ignoreImageAnalysis: [String]
}

struct DarkReaderFixesManager {
    static let shared = DarkReaderFixesManager()
    let fixes: [DarkReaderFix]
    
    init() {
        do {
            let path = Bundle.main.url(forResource: "darkreader-fixes", withExtension: "json")!
            let fileContent = try String(contentsOf: path).data(using: .utf8)!
            fixes = try JSONDecoder().decode([DarkReaderFix].self, from: fileContent)
        } catch {
            assertionFailure("Should be able to decode json \(error)")
            fixes = [DarkReaderFix]()
        }
    }
    
    func fixesForURL(_ url: URL) -> String {
        guard let currentDomain = url.host?.dropWWW() else { return "" }
        
        let fixes = fixes.filter { fix in
            return fix.url.contains(currentDomain)
        }
        if let fix = fixes.first {
            
            let encoded = try? JSONEncoder().encode(fix).utf8String()
            print("Returning FIX \(encoded)")
            return encoded ?? ""
        } else {
            return ""
        }
    }
}
