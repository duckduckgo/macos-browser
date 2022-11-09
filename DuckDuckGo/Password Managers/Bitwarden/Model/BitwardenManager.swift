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

    func initCommunication(applicationDidFinishLaunching: Bool)
    func sendHandshake()
    func refreshStatusIfNeeded()
    func cancelCommunication()

    func openBitwarden()

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

    private lazy var communicator: BitwardenCommunication = BitwardenCommunicator()

    func initCommunication(applicationDidFinishLaunching: Bool) {
        communicator.delegate = self

        // Check preferences to make sure Bitwarden is set as password manager
        let autofillPreferences = AutofillPreferences()
        guard autofillPreferences.passwordManager == .bitwarden else {
            // The built-in password manager is used
            return
        }

        connectToBitwadenProcess()
    }

    func cancelCommunication() {
        connectionAttemptTimer?.invalidate()
        connectionAttemptTimer = nil
        status = .disabled
        communicator.terminateProxyProcess()
        try? keyStorage.cleanSharedKey()
        openSSLWrapper.cleanKeys()
    }

    // MARK: - Installation

    private let installationManager = LocalBitwardenInstallationManager()

    func openBitwarden() {
        installationManager.openBitwarden()
    }


    // MARK: - Connection

    private func connectToBitwadenProcess() {
        // Check whether Bitwarden is installed
        guard installationManager.isBitwardenInstalled else {
            status = .notInstalled
            scheduleConnectionAttempt()
            return
        }

        // Check whether Bitwarden app is running
        guard RunningApplicationCheck.isApplicationRunning(bundleId: "com.bitwarden.desktop") else {
            status = .notRunning
            scheduleConnectionAttempt()
            return
        }

        // Check whether user approved integration with DuckDuckGo in Bitwarden
        guard installationManager.isIntegrationWithDuckDuckGoEnabled else {
            status = .integrationNotApproved
            scheduleConnectionAttempt()
            return
        }

        // Check wheter the onboarding flow finished successfully
        let sharedKey = try? keyStorage.retrieveSharedKey()
        if sharedKey == nil {
            // The onboarding flow wasn't finished successfully
            status = .missingHandshake
        } else {
            status = .connecting
        }

        // Run the proxy process
        do {
            try communicator.runProxyProcess()
        } catch {
            os_log("BitwardenManagement: Running of proxy process failed", type: .error)
            status = .error(error: .runningOfProxyProcessFailed)
            scheduleConnectionAttempt()
        }
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

            self?.connectToBitwadenProcess()
        }
    }

    private func cancelConnectionAndScheduleNextAttempt() {
        // Kill the proxy process and schedule the next attempt
        communicator.terminateProxyProcess()
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
            self?.sendStatus(withDelay: false)
        }
    }

    private func stopStatusRefreshing() {
        statusRefreshingTimer?.invalidate()
        statusRefreshingTimer = nil
    }

    // MARK: - Handling Incoming Messages

    private func handleCommand(_ command: BitwardenCommand) {
        switch command {
        case .connected:
            let sharedKey: Base64EncodedString?
            do {
                sharedKey = try keyStorage.retrieveSharedKey()
            } catch {
                status = .handshakeNotApproved
                assertionFailure("Failed to retrieve shared key")
                return
            }

            // If shared key retrieval is successfull, we already onboarded the user.
            if let sharedKey = sharedKey {
                guard let sharedKeyData = Data(base64Encoded: sharedKey),
                      openSSLWrapper.setSharedKey(sharedKeyData) else {
                    status = .error(error: .injectingOfSharedKeyFailed)
                    return
                }
                status = .waitingForTheStatusResponse
                sendStatus(withDelay: true)
            } else {
                // Onboarding is in progress
                // Other part of the code is responsible for sending the handshake message
            }
        case .disconnected:
            // Bitwarden application isn't running
            cancelConnectionAndScheduleNextAttempt()
            if status != .disabled {
                status = .notRunning
            }
        default:
            assertionFailure("Wrong handler")
        }
    }

    private func handleError(_ error: String, blocking: Bool) {
        switch error {
        case "cannot-decrypt":
            os_log("BitwardenManagement: Bitwarden error - cannot decrypt", type: .error)
            if blocking {
                status = .error(error: .bitwardenCannotDecrypt)
            }
            //TODO: callback
        default: os_log("BitwardenManagement: Bitwarden error - unknown", type: .error)
            status = .error(error: .bitwardenRespondedWithError)
        }
    }

    private func handleHandshakeResponse(encryptedSharedKey: String, status: String) {
        guard status == "success" else {
            self.status = .error(error: .handshakeFailed)
            cancelConnectionAndScheduleNextAttempt()
            return
        }

        guard let sharedKey = openSSLWrapper.decryptSharedKey(encryptedSharedKey) else {
            self.status = .error(error: .decryptionOfSharedKeyFailed)
            cancelConnectionAndScheduleNextAttempt()
            return
        }

        do {
            try keyStorage.save(sharedKey: sharedKey)
        } catch {
            self.status = .error(error: .storingOfTheSharedKeyFailed)
            return
        }

        sendStatus()
    }

    private func handleEncryptedResponse(_ encryptedPayload: BitwardenMessage.EncryptedPayload, messageId: MessageId) {
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

        switch message.command {
        case .credentialRetrieval:
            if let payload = message.payload {
                handleCredentialRetrievalResponse(messageId: messageId, payload: payload)
                return
            }
        case .credentialCreate:
            if case let .item(payloadIdem) = message.payload {
                handleCredentialCreationResponse(messageId: messageId, payloadItem: payloadIdem)
                return
            }
        case .credentialUpdate:
            if case let .item(payloadIdem) = message.payload {
                handleCredentialUpdateResponse(messageId: messageId, payloadItem: payloadIdem)
                return
            }

        default: break
        }

        //TODO: Refactor to use command for triage (as above)
        switch message.payload {
        case .array(let payloadItemArray):
            if payloadItemArray.first?.status != nil {
                handleStatusResponse(payloadItemArray: payloadItemArray)
                return
            }
        default: break
        }

        assertionFailure("Unhandled response")
    }

    private func handleStatusResponse(payloadItemArray: [BitwardenMessage.PayloadItem]) {
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

    private func handleCredentialRetrievalResponse(messageId: MessageId, payload: BitwardenMessage.Payload) {
        // TODO: Error
        if case let .array(payloadItemArray) = payload {
            let credentials = payloadItemArray.compactMap { BitwardenCredential(from: $0) }
            guard let completion = retrieveCredentialsCompletionCache[messageId] else {
                assertionFailure("Missing completion block")
                return
            }

            retrieveCredentialsCompletionCache[messageId] = nil
            completion(credentials, nil)
        }
    }

    private func handleCredentialCreationResponse(messageId: MessageId, payloadItem: BitwardenMessage.PayloadItem) {

        guard let completion = createCredentialCompletionCache[messageId] else {
            assertionFailure("Missing completion block")
            return
        }
        createCredentialCompletionCache[messageId] = nil

        if payloadItem.status == "success" {
            completion(nil)
        } else {
            completion(BitwardenError.credentialCreationFailed)
        }
    }

    private func handleCredentialUpdateResponse(messageId: MessageId, payloadItem: BitwardenMessage.PayloadItem) {

        guard let completion = updateCredentialCompletionCache[messageId] else {
            assertionFailure("Missing completion block")
            return
        }
        updateCredentialCompletionCache[messageId] = nil

        if payloadItem.status == "success" {
            completion(nil)
        } else {
            completion(BitwardenError.credentialUpdateFailed)
        }
    }

    // MARK: - Sending Messages

    func sendHandshake() {
        guard let publicKey = generateKeyPair() else {
            assertionFailure("Public key is missing")
            return
        }

        guard let messageData = BitwardenMessage.makeHandshakeMessage(with: publicKey).data else {
            assertionFailure("Making the handshake message failed")
            return
        }

        communicator.send(messageData: messageData)
    }

    private func sendStatus(withDelay: Bool = false) {
        guard let commandData = BitwardenMessage.EncryptedCommand(command: .status, payload: nil).data,
              let encryptedCommand = encryptCommandData(commandData),
              let messageData = BitwardenMessage.makeStatusMessage(encryptedCommand: encryptedCommand)?.data else {
            assertionFailure("Making the status message failed")
            status = .error(error: .sendingOfStatusMessageFailed)
            return
        }

        if withDelay {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.communicator.send(messageData: messageData)
            }
        } else {
            communicator.send(messageData: messageData)
        }
    }

    private func sendCredentialRetrieval(url: URL, messageId: MessageId) {
        let payload = BitwardenRequest.EncryptedCommand.Payload(uri: url.absoluteString)
        guard let commandData = BitwardenRequest.EncryptedCommand(command: .credentialRetrieval,
                                                                  payload: payload).data,
              let encryptedCommand = encryptCommandData(commandData),
              let messageData = BitwardenMessage.makeCredentialRetrievalMessage(encryptedCommand: encryptedCommand, messageId: messageId)?.data else {
            assertionFailure("Making the credential retrieval message failed")
            status = .error(error: .sendingOfStatusMessageFailed)
            return
        }

        communicator.send(messageData: messageData)
    }

    private func sendCredentialCreation(_ credential: BitwardenCredential, messageId: MessageId) {
        let payload = BitwardenRequest.EncryptedCommand.Payload(uri: credential.url,
                                                                userId: credential.userId,
                                                                userName: credential.username,
                                                                password: credential.password,
                                                                name: credential.credentialName)
        guard let commandData = BitwardenRequest.EncryptedCommand(command: .credentialCreate,
                                                                  payload: payload).data,
              let encryptedCommand = encryptCommandData(commandData),
              let messageData = BitwardenMessage.makeCredentialCreationMessage(encryptedCommand: encryptedCommand, messageId: messageId)?.data else {
            assertionFailure("Making the credential creation message failed")
            status = .error(error: .sendingOfStatusMessageFailed)
            return
        }

        communicator.send(messageData: messageData)
    }

    private func sendCredentialUpdate(_ credential: BitwardenCredential, messageId: MessageId) {
        let payload = BitwardenRequest.EncryptedCommand.Payload(uri: credential.url,
                                                                userId: credential.userId,
                                                                userName: credential.username,
                                                                password: credential.password,
                                                                name: credential.credentialName,
                                                                credentialId: credential.credentialId)
        guard let commandData = BitwardenRequest.EncryptedCommand(command: .credentialUpdate,
                                                                  payload: payload).data,
              let encryptedCommand = encryptCommandData(commandData),
              let messageData = BitwardenMessage.makeCredentialCreationMessage(encryptedCommand: encryptedCommand, messageId: messageId)?.data else {
            assertionFailure("Making the credential update message failed")
            status = .error(error: .sendingOfStatusMessageFailed)
            return
        }

        communicator.send(messageData: messageData)
    }

    private func encryptCommandData(_ commandData: Data) -> String? {
        guard let encryptedData = openSSLWrapper.encryptData(commandData) else {
            return nil
        }

#if DEBUG
        // Verify encryption
        let decryptedData = openSSLWrapper.decryptData(encryptedData.data, andIv: encryptedData.iv)
        assert(decryptedData.utf8String() != nil)
#endif

        return "2.\(encryptedData.iv.base64EncodedString())|\(encryptedData.data.base64EncodedString())|\(encryptedData.hmac.base64EncodedString())"
    }
    
    // MARK: - Encryption

    let openSSLWrapper = OpenSSLWrapper()

    private func generateKeyPair() -> Base64EncodedString? {
        return openSSLWrapper.generateKeys()
    }

    // MARK: - Shared Key Storage

    let keyStorage: BitwardenKeyStoring = BitwardenKeyStorage()

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
              let status = BitwardenVault.Status(rawValue: statusString) else {
            self.status = .error(error: .statusParsingFailed)
            return
        }

        let vault = BitwardenVault(id: id, email: email, status: status, active: true)
        self.status = .connected(vault: vault)
    }

    func refreshStatusIfNeeded() {
        switch status {
        case .connected(vault: _), .error(error: _): sendStatus()
        default: return
        }
    }

    // MARK: - Cretentials

    var retrieveCredentialsCompletionCache = [MessageId: ([BitwardenCredential], BitwardenError?) -> Void]()

    func retrieveCredentials(for url: URL, completion: @escaping ([BitwardenCredential], BitwardenError?) -> Void) {
        let messageId = BitwardenMessage.generateMessageId()
        retrieveCredentialsCompletionCache[messageId] = completion
        sendCredentialRetrieval(url: url, messageId: messageId)
    }

    var createCredentialCompletionCache = [MessageId: ((BitwardenError?) -> Void)]()

    func create(credential: BitwardenCredential, completion: @escaping (BitwardenError?) -> Void) {
        let messageId = BitwardenMessage.generateMessageId()
        createCredentialCompletionCache[messageId] = completion
        sendCredentialCreation(credential, messageId: messageId)
    }

    var updateCredentialCompletionCache = [MessageId: ((BitwardenError?) -> Void)]()

    func update(credential: BitwardenCredential, completion: @escaping (BitwardenError?) -> Void) {
        let messageId = BitwardenMessage.generateMessageId()
        updateCredentialCompletionCache[messageId] = completion
        sendCredentialUpdate(credential, messageId: messageId)
    }

}

extension BitwardenManager: BitwardenCommunicatorDelegate {

    func bitwadenCommunicatorProcessDidTerminate(_ bitwardenCommunicator: BitwardenCommunication) {
        status = .notRunning

        scheduleConnectionAttempt()
    }


    func bitwadenCommunicator(_ bitwardenCommunicator: BitwardenCommunication, didReceiveMessageData messageData: Data) {
        guard let message = BitwardenMessage(from: messageData) else {
            assertionFailure("Can't decode the message")
            return
        }

        //TODO: check id of received message. Throw away not requested messages.

        if let command = message.command, command == .connected || command == .disconnected {
            handleCommand(command)
            return
        }

        //TODO: Make the error blocking for certain messages
        if case let .item(payloadItem) = message.payload {
            if let error = payloadItem.error {
                handleError(error, blocking: false)
                return
            }

            if let encryptedSharedKey = payloadItem.sharedKey,
               let status = payloadItem.status {
                handleHandshakeResponse(encryptedSharedKey: encryptedSharedKey, status: status)
                return
            }
        }

        if let encryptedPayload = message.encryptedPayload, let messageId = message.messageId {
            handleEncryptedResponse(encryptedPayload, messageId: messageId)
            return
        }

        assertionFailure("Unhandled message from Bitwarden")
    }
}
