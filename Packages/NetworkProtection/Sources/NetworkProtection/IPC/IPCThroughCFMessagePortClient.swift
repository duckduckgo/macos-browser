//
//  IPCThroughCFMessagePortClient.swift
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
extension IPCThroughCFMessagePort {

    public enum SendError: Error {
        case couldNotCreateMessagePort
    }

    public final class Client {
        private let portName: String
        private var isRunning = false
        private var messageIDCounter = Int32(0)

        public init(portName: String = IPCThroughCFMessagePort.defaultMessagePort) {
            self.portName = portName
        }

        public func send(_ data: Data) throws -> MessageResult {
            var output: Unmanaged<CFData>?
            let currentMessageID = messageIDCounter + 1
            messageIDCounter = currentMessageID

            guard let messagePort = CFMessagePortCreateRemote(nil, portName as CFString) else {
                throw SendError.couldNotCreateMessagePort
            }

            let status = CFMessagePortSendRequest(messagePort, currentMessageID, data as CFData, defaultTimeout, defaultTimeout, CFRunLoopMode.defaultMode.rawValue, &output)

            let response = output?.takeRetainedValue() as? Data

            return MessageResult.make(fromStatus: status, messageID: currentMessageID, response: response)
        }
    }
}
