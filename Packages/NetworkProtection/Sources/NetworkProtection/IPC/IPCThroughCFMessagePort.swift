//
//  IPCThroughCFMessagePort.swift
//  DuckDuckGo
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
import os.log

public final class IPCThroughCFMessagePort {
    public static let defaultMessagePort = AppGroupHelper.shared.appGroup
    public static let defaultEncoding = String.Encoding.utf8
    public static let defaultTimeout: TimeInterval = .seconds(1)

    public enum MessageResult {
        case success(messageID: Int32, response: Data?)
        case sendTimeout
        case receiveTimeout
        case isInvalid
        case transportError
        case becameInvalidError
        case unknownError(status: Int32)

        static func make(fromStatus status: Int32, messageID: Int32, response: Data?) -> MessageResult {
            switch status {
            case kCFMessagePortSuccess:
                return .success(messageID: messageID, response: response)
            case kCFMessagePortSendTimeout:
                return .sendTimeout
            case kCFMessagePortReceiveTimeout:
                return .receiveTimeout
            case kCFMessagePortIsInvalid:
                return .isInvalid
            case kCFMessagePortTransportError:
                return .transportError
            case kCFMessagePortBecameInvalidError:
                return .becameInvalidError
            default:
                return .unknownError(status: status)
            }
        }
    }
}
