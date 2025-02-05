//
//  AppInfo.swift
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

import AppKit

public struct AppInfo: Equatable {
    public let bundleID: String
    public let name: String
    public let icon: NSImage?

    public init(bundleID: String, name: String, icon: NSImage?) {
        self.bundleID = bundleID
        self.name = name
        self.icon = icon
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}
