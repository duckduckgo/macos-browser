//
//  SyncDevice.swift
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

public struct SyncDevice: Identifiable, Equatable {

    public enum Kind: Equatable {
        case current, desktop, mobile
    }

    public let kind: Kind
    public let name: String
    public let id: String

    public init(kind: Kind, name: String, id: String) {
        self.kind = kind
        self.name = name
        self.id = id
    }

    public var isCurrent: Bool {
        kind == .current
    }
}
