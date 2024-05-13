//
//  IPCMetadataCollector.swift
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

public protocol IPCMetadataCollector {
    static var version: String { get }
    static var bundlePath: String { get }
}

final public class DefaultIPCMetadataCollector: IPCMetadataCollector {
    public static var version: String {
        shortVersion + "/" + buildNumber
    }

    public static var bundlePath: String {
        Bundle.main.bundlePath
    }

    // swiftlint:disable force_cast
    private static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }

    private static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    }
    // swiftlint:enable force_cast
}
