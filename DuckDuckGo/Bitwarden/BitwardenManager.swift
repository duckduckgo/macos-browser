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

protocol BitwardenManagement {

    var status: BitwardenStatus { get }
    var statusPublisher: Published<BitwardenStatus>.Publisher { get }

    func sendHandshake()

    func retrieveCredentials(for url: URL, completion: @escaping ([BitwardenCredential], BitwardenError?) -> Void)
    func create(credential: BitwardenCredential, completion: @escaping (BitwardenError?) -> Void)
    func update(credential: BitwardenCredential, completion: @escaping (BitwardenError?) -> Void)

}

final class BitwardenManager: BitwardenManagement, ObservableObject {

    static let shared = BitwardenManager()

    private init() {}

    init(communicator: BitwardenCommunication) {
        self.communicator = communicator
    }

    private lazy var communicator: BitwardenCommunication = BitwardenComunicator()

    func initCommunication() {
        //TODO: adjust the init based on internal setting of password manager and subscribe for dynamic change of the setting
        //TODO: Retrieve keys if possible instead of generation

        generateKeyPair()
        communicator.delegate = self
        startConnection()
    }

    // MARK: - Connection

    private func startConnection() {
        guard RunningApplicationCheck.isApplicationRunning(bundleId: "com.bitwarden.desktop") else {
            scheduleConnectionAttempt()
            return
        }

        communicator.enabled = true
    }

    private var connectionAttemptTimer: Timer?

    // Disables communicator (kills the proxy process)
    // and schedules future attempt to connect
    private func scheduleConnectionAttempt() {
        guard connectionAttemptTimer == nil else {
            //Already scheduled
            return
        }

        connectionAttemptTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] timer in
            self?.connectionAttemptTimer?.invalidate()
            self?.connectionAttemptTimer = nil

            self?.startConnection()
        }
    }

    private func cancelConnectionAndScheduleNextAttempt() {
        // Kill the proxy process and schedule the next attempt
        communicator.enabled = false
        scheduleConnectionAttempt()
    }

    // MARK: - Status Refreshing

    private var statusRefreshingTimer: Timer?

    // Disables communicator (kills the proxy process)
    // and schedules future attempt to connect
    private func scheduleStatusRefreshing() {
        guard statusRefreshingTimer == nil else {
            //Already scheduled
            return
        }

        statusRefreshingTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            self?.sendStatus()
        }
    }

    private func stopStatusRefreshing() {
        statusRefreshingTimer?.invalidate()
        statusRefreshingTimer = nil
    }

    // MARK: - Handling Incoming Messages

    private func handleCommand(_ command: BitwardenMessage.Command) {
        switch command {
        case .connected:
            status = .approachable
            
            // The handshake should only be sent automatically if the Bitwarden integration flow has already been completed:
            if AutofillPreferences().passwordManager == .bitwarden {
                sendHandshake()
            }

            return
        case .disconnected:
            // Bitwarden application isn't running || User didn't approve DuckDuckGo browser integration
            cancelConnectionAndScheduleNextAttempt()
            status = .notApproachable
        default:
            assertionFailure("Wrong handler")
        }
    }

    private func handleError(_ error: String) {
        switch error {
        case "cannot-decrypt": os_log("BitwardenManagement: Bitwarden error - cannot decrypt", type: .error)
        default: os_log("BitwardenManagement: Bitwarden error - unknown", type: .error)
        }
    }

    private func handleHandshakeResponse(encryptedSharedKey: String, status: String) {
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

    private func handleEncryptedResponse(_ encryptedPayload: BitwardenMessage.EncryptedPayload) {
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
        os_log("Decrypted payload:\n %s", log: .bitwarden, type: .default, decryptedString ?? "")
        #endif

        guard let message = BitwardenMessage(from: decryptedData) else {
            status = .error(error: .parsingFailed)
            return
        }

        switch message.payload {
        case .item:
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

        // If vault is locked, keep refreshing the latest status
        if case .connected(vault: let vault) = status,
           vault.status == .locked {
            scheduleStatusRefreshing()
        } else {
            stopStatusRefreshing()
        }
    }

    // MARK: - Sending Messages

    func sendHandshake() {
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
        guard let commandData = BitwardenMessage.EncryptedCommand(command: .status, payload: nil).data else {
            assertionFailure("Making the status message failed")
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
    
    // MARK: - Encryption and Keys

    let openSSLWrapper = OpenSSLWrapper()

    // TODO: Remove optional type to make sure the key is read or generated.
    var publicKey: String?

    private func generateKeyPair() {
        publicKey = openSSLWrapper.generateKeys()
    }

    // MARK: - Status

    @Published private(set) var status: BitwardenStatus = .disabled {
        didSet {
            os_log("Status changed: %s", log: .bitwarden, type: .default, String(describing: status))
        }
    }
    var statusPublisher: Published<BitwardenStatus>.Publisher { $status }

    private func refreshStatus(payloadItem: BitwardenMessage.PayloadItem) {
        guard let id = payloadItem.id,
              let email = payloadItem.email,
              let statusString = payloadItem.status,
              let status = BitwardenStatus.Vault.Status(rawValue: statusString) else {
            self.status = .error(error: .statusParsingFailed)
            return
        }

        let vault = BitwardenStatus.Vault(id: id, email: email, status: status, active: true)
        self.status = .connected(vault: vault)
    }

    // MARK: - Cretentials

    func retrieveCredentials(for url: URL, completion: @escaping ([BitwardenCredential], BitwardenError?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let credentials = [
                BitwardenCredential(userId: "user-id",
                                    credentialId: "credential-id-1",
                                    credentialName: "domain.com",
                                    username: "username",
                                    password: "password123",
                                    url: url),
                BitwardenCredential(userId: "user-id",
                                           credentialId: "credential-id-2",
                                           credentialName: "domain2.com",
                                           username: "duck",
                                           password: "password123",
                                           url: url)
            ]
            completion(credentials, nil)
        }
    }

    func create(credential: BitwardenCredential, completion: @escaping (BitwardenError?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion(nil)
        }
    }

    func update(credential: BitwardenCredential, completion: @escaping (BitwardenError?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion(nil)
        }
    }

}

extension BitwardenManager: BitwardenCommunicatorDelegate {

    func bitwadenCommunicator(_ bitwardenCommunicator: BitwardenComunicator, didReceiveMessageData messageData: Data) {

        guard let message = BitwardenMessage(from: messageData) else {
            assertionFailure("Can't decode the message")
            return
        }
        
        //TODO: check id of received message. Throw away not requested messages.

        if let command = message.command, command == .connected || command == .disconnected {
            handleCommand(command)
            return
        }

        if case let .item(payloadItem) = message.payload {
            if let error = payloadItem.error {
                handleError(error)
                return
            }

            if let encryptedSharedKey = payloadItem.sharedKey,
               let status = payloadItem.status {
                handleHandshakeResponse(encryptedSharedKey: encryptedSharedKey, status: status)
                return
            }
        }

        if let encryptedPayload = message.encryptedPayload {
            handleEncryptedResponse(encryptedPayload)
            return
        }

        assertionFailure("Unhandled message from Bitwarden")
    }
}
