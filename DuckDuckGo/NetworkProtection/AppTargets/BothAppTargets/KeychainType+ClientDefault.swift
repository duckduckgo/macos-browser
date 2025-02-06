//
//  KeychainType+ClientDefault.swift
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
import NetworkProtection
import Common

/// Implements convenience default for the client apps making use of this.
///
/// If you add this to a new target, please make sure this default is the correct one for the target.
/// Because the default may not be right for all targets, please avoid sharing this in a framework directly.
/// This is meant to be a client-specific definition by its own nature.
///
extension KeychainType {
    static let `default`: KeychainType = .dataProtection(.named(Bundle.main.appGroup(bundle: .netP)))
}
