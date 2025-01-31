//
//  NativeMessagingConnection.swift
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
import os.log

@available(macOS 14.4, *)
protocol NativeMessagingConnectionDelegate: AnyObject {

    func nativeMessagingConnectionProcessDidFail(_ nativeMessagingConnection: NativeMessagingConnection)

}

@available(macOS 14.4, *)
final class NativeMessagingConnection {
    let port: _WKWebExtension.MessagePort
    let communicator: NativeMessagingCommunicator

    weak var delegate: NativeMessagingConnectionDelegate?

    internal init(port: _WKWebExtension.MessagePort, communicator: NativeMessagingCommunicator) {
        self.port = port
        self.communicator = communicator

        // Enable running proxy process when the application path in native messaging
        // communicator is corrrect
//        do {
//            try communicator.runProxyProcess()
//        } catch {
//            Logger.webExtensions.error("NativeMessagingConnection: Running proxy process failed")
//            delegate?.nativeMessagingConnectionProcessDidFail(self)
//        }
    }
}
