//
//  GPCTests.swift
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

import XCTest
import AppKit
import BrowserServicesKit

@testable import DuckDuckGo_Privacy_Browser

// MARK: - GPCTestData
private struct GPCTestData: Codable {
    let gpcHeader: GpcHeader
    let gpcJavaScriptAPI: GpcJavaScriptAPI
}

// MARK: - GpcHeader
struct GpcHeader: Codable {
    let name, desc: String
    let tests: [GpcHeaderTest]
}

// MARK: - GpcHeaderTest
struct GpcHeaderTest: Codable {
    let name: String
    let siteURL: String
    let requestURL: String
    let requestType: String
    let gpcUserSettingOn, expectGPCHeader: Bool
    let expectGPCHeaderValue: String?
    let exceptPlatforms: [String]
}

// MARK: - GpcJavaScriptAPI
struct GpcJavaScriptAPI: Codable {
    let name, desc: String
    let tests: [GpcJavaScriptAPITest]
}

// MARK: - GpcJavaScriptAPITest
struct GpcJavaScriptAPITest: Codable {
    let name: String
    let siteURL: String
    let gpcUserSettingOn, expectGPCAPI: Bool
    let expectGPCAPIValue: String?
    let exceptPlatforms: [String]
    let frameURL: String?
}

// Config Reference

// MARK: - ConfigReferenceData
private struct ConfigReferenceData: Codable {
    let readme: String
    let features: Features
    let version: Int
    let unprotectedTemporary: [UnprotectedTemporary]
}

// MARK: - Features
struct Features: Codable {
    let gpc: Gpc
}

// MARK: - Gpc
struct Gpc: Codable {
    let state: String
    let exceptions: [UnprotectedTemporary]
}

// MARK: - UnprotectedTemporary
struct UnprotectedTemporary: Codable {
    let domain, reason: String
}

enum FileError: Error {
    case unknownFile
    case invalidFileContents
}

final class FileLoader {

    func load(filePath: String, fromBundle bundle: Bundle) throws -> Data {
        
        guard let resourceUrl = bundle.resourceURL else { throw FileError.unknownFile }
        
        let url = resourceUrl.appendingPathComponent(filePath)
        
        let finalURL: URL
        if FileManager.default.fileExists(atPath: url.path) {
            finalURL = url
        } else {
            // Workaround for resource bundle having a different structure when running tests from command line.
            let url = resourceUrl.deletingLastPathComponent().appendingPathComponent(filePath)
            
            if FileManager.default.fileExists(atPath: url.path) {
                finalURL = url
            } else {
                throw FileError.unknownFile
            }
        }

        guard let data = try? Data(contentsOf: finalURL, options: [.mappedIfSafe]) else { throw  FileError.invalidFileContents }
        return data
    }
}


final class GPCTests: XCTestCase {
    private enum Resource {
        static let config = "global-privacy-control/config_reference.json"
        static let tests = "global-privacy-control/tests.json"
    }
         
    
    private func data(for path: String, in bundle: Bundle) throws -> Data {
        let url = bundle.resourceURL!.appendingPathComponent(path)
        let path: String
        
        if #available(macOS 13.0, *) {
            path = url.path(percentEncoded: true)
        } else {
            path = url.path
        }
        return try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
    }
    
    private func decodeResource<T: Decodable>(_ path: String, from bundle: Bundle) -> T {
    
        do {
            let data = try data(for: path, in: bundle)
            let jsonResult = try JSONDecoder().decode(T.self, from: data)
            return jsonResult
            
        } catch {
            XCTAssert(false, error.localizedDescription)
        }
        
        fatalError("Can't decode \(path)")
    }
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample()  {
        let bundle = Bundle(for: GPCTests.self)

        let tests: GPCTestData = decodeResource(Resource.tests, from: bundle)

        guard let configData = try? data(for: Resource.config, in: bundle) else {
            XCTAssert(false, "can't decode data")
            return
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: configData, options: []) as? [String: Any] else {
            XCTAssert(false, "can't decode data")
            return
        }

        let domain = MockDomainsProtectionStore()
        let configurationData = PrivacyConfigurationData(json: json)
        let privacyConfigurationData = AppPrivacyConfiguration(data: configurationData, identifier: "test", localProtection: domain)

        for test in tests.gpcHeader.tests {
            print("--------")
            if test.exceptPlatforms.contains("macos-browser") {
                print("Skipping test, ignore platform for [\(test.name)]")
                continue
            }
            
            print("Testing \(test.name)...")
  
            let preferences = PrivacySecurityPreferences.shared
            
            preferences.gpcEnabled = test.gpcUserSettingOn
            
            let factory = GPCRequestFactory(privacySecurityPreferences: preferences)
            var testRequest = URLRequest(url: URL(string: test.requestURL)!)
            testRequest.addValue("DDG-Test", forHTTPHeaderField: "User-Agent")

            let request = factory.requestForGPC(basedOn: testRequest, config: privacyConfigurationData)
            
            if !test.gpcUserSettingOn {
                XCTAssertNil(request, "User opt out, request should not exist \([test.name])")
            }
            
            let hasHeader = request?.allHTTPHeaderFields?[GPCRequestFactory.Constants.secGPCHeader] != nil
            let headerValue = request?.allHTTPHeaderFields?[GPCRequestFactory.Constants.secGPCHeader]

            if test.expectGPCHeader {
                XCTAssertNotNil(request, "Request should exist if expectGPCHeader is true [\(test.name)]")
                XCTAssert(hasHeader, "Couldn't find header for [\(test.requestURL)]")
                
                if let expectedHeaderValue = test.expectGPCHeaderValue {
                    let headerValue = request?.allHTTPHeaderFields?[GPCRequestFactory.Constants.secGPCHeader]
                    XCTAssertEqual(expectedHeaderValue, headerValue, "Header should be equal [\(test.name)]")
                }
            } else {
                XCTAssertNil(headerValue, "Header value should not exist [\(test.name)]")
            }
        }
    }
}
