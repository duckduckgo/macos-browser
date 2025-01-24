//
//  NativeMessagingHandler.swift
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
final class NativeMessagingHandler {

    var nativeMessagingConnections = [NativeMessagingConnection]()

    private func connection(for port: _WKWebExtension.MessagePort) -> NativeMessagingConnection? {
        return nativeMessagingConnections.first(where: { $0.port === port })
    }

    private func connection(for communicator: NativeMessagingCommunicator) -> NativeMessagingConnection? {
        return nativeMessagingConnections.first(where: {communicator === $0.communicator})
    }

    private func cancelConnection(_ connection: NativeMessagingConnection) {
        nativeMessagingConnections.removeAll {$0 === connection}
    }

    private func cancelConnection(with port: _WKWebExtension.MessagePort) {
        nativeMessagingConnections.removeAll { $0.port === port }
    }

    private func cancelConnection(with communicator: NativeMessagingCommunicator) {
        nativeMessagingConnections.removeAll {$0.communicator === communicator}
    }

    func webExtensionController(_ controller: _WKWebExtensionController, sendMessage message: Any, to applicationIdentifier: String?, for extensionContext: _WKWebExtensionContext) async throws -> Any? {
        // Handle browser.runtime.sendNativeMessage()
        return nil
    }

    func webExtensionController(_ controller: _WKWebExtensionController, connectUsingMessagePort port: _WKWebExtension.MessagePort, for extensionContext: _WKWebExtensionContext) async throws {
        port.disconnectHandler = { [weak self] error in
            if let error {
                Logger.webExtensions.log(("Message port disconnected: \(error)"))
            }
            self?.cancelConnection(with: port)
        }

        port.messageHandler = { [weak self] (message, error) in
            if let error {
                Logger.webExtensions.log(("Message handler error: \(error)"))
            }

            guard let message = message as? String else {
                assertionFailure("Unknown type of the message")
                return
            }

            Logger.webExtensions.log(("Received message from web extension: \(message)"))

            guard let connection = self?.connection(for: port) else {
                assertionFailure("Connection not found")
                return
            }

            let jsonData: Data
            do {
                jsonData = try JSONEncoder().encode(message)
            } catch {
                assertionFailure("Encoding error")
                Logger.webExtensions.log(("Failed to encode the message: \(message)"))
                jsonData = Data()
            }

            connection.communicator.send(messageData: jsonData)
        }

        // ⚠️ Missing application path
        // Detect the application path from the appropriate extension file
        let communicator = NativeMessagingCommunicator(appPath: "", arguments: [])
        communicator.delegate = self
        let connection = NativeMessagingConnection(port: port,
                                                   communicator: communicator)
        nativeMessagingConnections.append(connection)
    }
}

@available(macOS 14.4, *)
@MainActor
extension NativeMessagingHandler: @preconcurrency NativeMessagingCommunicatorDelegate {
    func nativeMessagingCommunicator(_ nativeMessagingCommunicator: any NativeMessagingCommunication, didReceiveMessageData messageData: Data) {

        guard let nativeMessagingCommunicator = nativeMessagingCommunicator as? NativeMessagingCommunicator else {
            assertionFailure("Unknown type of native messaging communicator")
            return
        }

        handleReceivedMessageData(messageData, communicator: nativeMessagingCommunicator)
    }

    private func handleReceivedMessageData(_ messageData: Data, communicator: NativeMessagingCommunicator) {
        guard let connection = connection(for: communicator) else {
            assertionFailure("Connection not found")
            return
        }

        do {
            let decodedMessage = try JSONDecoder().decode(String.self, from: messageData)
            Logger.webExtensions.log("Message received: \(decodedMessage)")
            connection.port.sendMessage(decodedMessage)
        } catch {
            assertionFailure("Failed to decode message")
            Logger.webExtensions.log(("Failed to decode the message: \(String(data: messageData, encoding: .utf8) ?? "")"))
        }
    }

    func nativeMessagingCommunicatorProcessDidTerminate(_ nativeMessagingCommunicator: any NativeMessagingCommunication) {
        Logger.webExtensions.log(("Process for native messaging terminated"))

        guard let nativeMessagingCommunicator = nativeMessagingCommunicator as? NativeMessagingCommunicator else {
            assertionFailure("Unknown type of native messaging communicator")
            return
        }

        cancelConnection(with: nativeMessagingCommunicator)
    }

}

@available(macOS 14.4, *)
@MainActor
extension NativeMessagingHandler: @preconcurrency NativeMessagingConnectionDelegate {

    func nativeMessagingConnectionProcessDidFail(_ nativeMessagingConnection: NativeMessagingConnection) {
        cancelConnection(nativeMessagingConnection)
    }

}
