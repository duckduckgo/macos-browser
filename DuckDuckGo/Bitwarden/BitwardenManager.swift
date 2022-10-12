//
//  BitwardenManager.swift
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
import SwiftUI
import OpenSSL
import os.log

// TODO: Rename to BitwardenController
protocol BitwardenManagement {

    var status: BitwardenStatus { get }
    var statusPublisher: Published<BitwardenStatus>.Publisher { get }

}

final class BitwardenManager {

    static let shared = BitwardenManager()

    //TODO: adjust the init based on internal setting of password manager and subscribe for dynamic change

    var status: BitwardenStatus = .disabled {
        didSet {
            os_log("Status changed: %s", log: .bitwarden, type: .default, String(describing: status))
        }
    }

    private lazy var communicator: BitwardenCommunication = BitwardenComunicator()

    private init() {}

    init(communicator: BitwardenCommunication) {
        self.communicator = communicator
    }

    func initCommunication() {
        generateKeyPair()
        communicator.delegate = self
        communicator.enabled = true
    }

    private var connectionAttemptTimer: Timer?

    // Disables communicator (kills the proxy process)
    // and schedules future attempt to connect
    private func scheduleConnectionAttempt() {
        connectionAttemptTimer?.invalidate()
        connectionAttemptTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] timer in
            self?.connectionAttemptTimer?.invalidate()
            self?.connectionAttemptTimer = nil

            self?.communicator.enabled = true
        }
    }

    private func cancelConnectionAndScheduleNextAttempt() {
        // Kill the proxy process and schedule the next attempt
        communicator.enabled = false
        scheduleConnectionAttempt()
    }

    private func refreshStatus(payloadItem: BitwardenMessage.PayloadItem) {
        guard let id = payloadItem.id,
              let email = payloadItem.email,
              let statusString = payloadItem.status,
              let status = BitwardenStatus.Vault.Status(rawValue: statusString) else {
            self.status = .error(error: .statusParsingFailed)
            return
        }

        let vault = BitwardenStatus.Vault(id: id, email: email, status: status)
        self.status = .connected(vault: vault)
    }

    // MARK: - Handling Incoming Messages

    private func handleCommand(_ command: String) {
        switch command {
        case "connected":
            sendHandshake()
            return
        case "disconnected":
            // Bitwarden application isn't running || User didn't approve DuckDuckGo browser integration
            cancelConnectionAndScheduleNextAttempt()
        default:
            assertionFailure("Unknown command")
        }
    }

    private func handleHandshakeResponce(encryptedSharedKey: String, status: String) {
        guard status == "success" else {
            self.status = .error(error: .handshakeFailed)
            cancelConnectionAndScheduleNextAttempt()
            return
        }

        guard openSSLWrapper.decryptSharedKey(encryptedSharedKey) else {
            self.status = .error(error: .decryptionOfSharedKeyFailed)
            cancelConnectionAndScheduleNextAttempt()
            return
        }

        sendStatus()
    }

    private func handleEncryptedResponce(_ encryptedPayload: BitwardenMessage.EncryptedPayload) {
        guard let dataString = encryptedPayload.data,
              let data = Data(base64Encoded: dataString),
              let ivDataString = encryptedPayload.iv,
              let ivData = Data(base64Encoded: ivDataString)
        else {
            status = .error(error: .parsingFailed)
            return
        }

        let decryptedData = openSSLWrapper.decryptData(data, andIv:ivData)
        guard decryptedData.count > 0 else {
            status = .error(error: .decryptionOfDataFailed)
            return
        }

        #if DEBUG
        let decryptedString = String(bytes: decryptedData, encoding: .utf8)
        os_log("Decrypted payload: %s", log: .bitwarden, type: .default, decryptedString ?? "")
        #endif

        guard let message = BitwardenMessage(from: decryptedData) else {
            status = .error(error: .parsingFailed)
            return
        }

        switch message.payload {
        case .item(let payloadItem):
            //TODO: Handle other messages
            assertionFailure("Unhandled case")
        case .array(let payloadItemArray):
            if payloadItemArray.first?.status != nil {
                handleStatusResponce(payloadItemArray: payloadItemArray)
            }
        case .none:
            //TODO: Handle none
            assertionFailure("Unhandled case")
            return
        }

    }

    private func handleStatusResponce(payloadItemArray: [BitwardenMessage.PayloadItem]) {
        // Find the active vault
        guard let activePayloadItem = payloadItemArray.filter({ $0.active ?? false }).first else {
            status = .error(error: .noActiveVault)
            return
        }

        refreshStatus(payloadItem: activePayloadItem)
    }

    // MARK: - Sending Messages

    private func sendHandshake() {
        guard let publicKey64Encoded = publicKey else {
            assertionFailure("Public key is missing")
            return
        }

        guard let messageData = BitwardenMessage.makeHandshakeMessage(with: publicKey64Encoded).data else {
            assertionFailure("Making the handshake message failed")
            return
        }

        communicator.send(messageData: messageData)
    }

    private func sendStatus() {
        //TODO: More general encryption method
        let command = BitwardenMessage.EncryptedCommand(command: "bw-status", payload: nil)
        guard let commandData = try? JSONEncoder().encode(command) else {
            assertionFailure("JSON encoding failed")
            return
        }
        let encryptedData = openSSLWrapper.encryptData(commandData)
        let encryptedCommand = "2.\(encryptedData.iv.base64EncodedString())|\(encryptedData.data.base64EncodedString())|\(encryptedData.hmac.base64EncodedString())"

        guard let messageData = BitwardenMessage.makeStatusMessage(encryptedCommand: encryptedCommand)?.data else {
            assertionFailure("Making the status message failed")
            return
        }

        communicator.send(messageData: messageData)
    }
    
    // MARK: - Keys

    let openSSLWrapper = OpenSSLWrapper()

    var publicKey: String?
    var sharedKey: String?

    private func generateKeyPair() {
        publicKey = openSSLWrapper.generateKeys()
    }

}

extension BitwardenManager: BitwardenCommunicatorDelegate {

    func bitwadenCommunicator(_ bitwardenCommunicator: BitwardenComunicator, didReceiveMessageData messageData: Data) {

        guard let message = BitwardenMessage(from: messageData) else {
            assertionFailure("Can't decode the message")
            return
        }

        //TODO: check id of received message. Throw away not requested messages.

        if let command = message.command {
            handleCommand(command)
            return
        }

        if case let .item(payloadItem) = message.payload,
              let encryptedSharedKey = payloadItem.sharedKey,
              let status = payloadItem.status {
            handleHandshakeResponce(encryptedSharedKey: encryptedSharedKey, status: status)
            return
        }

        if let encryptedPayload = message.encryptedPayload {
            handleEncryptedResponce(encryptedPayload)
            return
        }

        assertionFailure("Unhandled message from Bitwarden: %s")
    }

}
