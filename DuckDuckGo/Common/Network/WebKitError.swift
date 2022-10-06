//
//  WebKitError.swift
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
import WebKit

struct WebKitError: Error, Hashable, _BridgedStoredNSError, CustomNSError {

    typealias _ErrorType = Code // swiftlint:disable:this type_name
    var _nsError: NSError // swiftlint:disable:this identifier_name

    public struct Code: RawRepresentable, Hashable, _ErrorCodeProtocol {
        public typealias _ErrorType = WebKitError // swiftlint:disable:this type_name

        let rawValue: Int
    }

    static let frameLoadInterrupted = WebKitError.Code(rawValue: WebKitErrorFrameLoadInterruptedByPolicyChange)
    static let cannotShowMIMEType = WebKitError.Code(rawValue: WebKitErrorCannotShowMIMEType)
    static let cannotShowURL = WebKitError.Code(rawValue: WebKitErrorCannotShowURL)
    static let frameLoadInterruptedByPolicyChange = WebKitError.Code(rawValue: WebKitErrorFrameLoadInterruptedByPolicyChange)
    static let cannotFindPlugIn = WebKitError.Code(rawValue: WebKitErrorCannotFindPlugIn)
    static let cannotLoadPlugIn = WebKitError.Code(rawValue: WebKitErrorCannotLoadPlugIn)
    static let javaUnavailable = WebKitError.Code(rawValue: WebKitErrorJavaUnavailable)
    static let blockedPlugInVersion = WebKitError.Code(rawValue: WebKitErrorBlockedPlugInVersion)

}
