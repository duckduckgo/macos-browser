//
//  DownloadResumeData.swift
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

struct DownloadResumeData {

    private enum CodingKeys {
        static let root = "NSKeyedArchiveRootObjectKey"

        static let localPath = "NSURLSessionResumeInfoLocalPath"
        static let tempFileName = "NSURLSessionResumeInfoTempFileName"
    }

    private var dict: [String: Any]

    var localPath: String? {
        get {
            dict[CodingKeys.localPath] as? String
        }
        set {
            dict[CodingKeys.localPath] = newValue
        }
    }

    var tempFileName: String? {
        get {
            dict[CodingKeys.tempFileName] as? String
        }
        set {
            dict[CodingKeys.tempFileName] = newValue
        }
    }

    init(resumeData: Data) throws {
        // https://github.com/WebKit/WebKit/blob/b4ac73768e74d52bf877a1c466eeee4408f291c2/Source/WebKit/UIProcess/API/Cocoa/WKWebView.mm#L829
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: resumeData)
        let object = unarchiver.decodeObject(of: [NSDictionary.self, NSArray.self, NSString.self, NSNumber.self, NSData.self, NSURL.self, NSURLRequest.self], forKey: CodingKeys.root)
        unarchiver.finishDecoding()

        dict = try object as? [String: Any] ?? {
            throw unarchiver.error ?? CocoaError(.coderReadCorrupt)
        }()
    }

    func data() throws -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.encode(dict, forKey: CodingKeys.root)
        archiver.finishEncoding()
        if let error = archiver.error {
            throw error
        }
        return archiver.encodedData
    }

}
