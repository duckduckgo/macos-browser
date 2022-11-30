//
//  BWManager.swift
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

protocol BWManagement {

    var status: BWStatus { get }
    var statusPublisher: Published<BWStatus>.Publisher { get }

    func initCommunication()
    func sendHandshake()
    func refreshStatusIfNeeded()
    func cancelCommunication()

    func openBitwarden()

    func retrieveCredentials(for url: URL, completion: @escaping ([BWCredential], BWError?) -> Void)
    func create(credential: BWCredential, completion: @escaping (BWError?) -> Void)
    func update(credential: BWCredential, completion: @escaping (BWError?) -> Void)

}

final class BWManager: BWManagement, ObservableObject {

    static let shared = BWManager()
    static let bundleId = "com.bitwarden.desktop"
    static let applicationName = "Bitwarden"

    private init() {}

    init(communicator: BWCommunication) {
        self.communicator = communicator
    }

    private lazy var communicator: BWCommunication = BWCommunicator()

    func initCommunication() {
        communicator.delegate = self

        connectToBitwardenProcess()
    }

    func cancelCommunication() {
        connectionAttemptTimer?.invalidate()
        connectionAttemptTimer = nil
        status = .disabled
        communicator.terminateProxyProcess()
        try? keyStorage.cleanSharedKey()
        encryption.cleanKeys()
    }

    // MARK: - Installation

    private let installationService = LocalBitwardenInstallationService()

    func openBitwarden() {
        installationService.openBitwarden()
    }


    // MARK: - Connection

    var isBitwardenPasswordManager: Bool {
        let autofillPreferences = AutofillPreferences()
        return autofillPreferences.passwordManager == .bitwarden
    }

    private func connectToBitwardenProcess() {
        // Check preferences to make sure Bitwarden is set as password manager
        guard isBitwardenPasswordManager else {
            // The built-in password manager is used
            return
        }

        // Check whether Bitwarden is installed and make sure it supports the integration
        switch installationService.installationState {
        case .notInstalled:
            status = .notInstalled
            scheduleConnectionAttempt()
            return
        case .oldVersion:
            status = .oldVersion
            scheduleConnectionAttempt()
            return
        case .installed:
            break
        }

        // Check whether Bitwarden app is running
        guard RunningApplicationCheck.isApplicationRunning(bundleId: Self.bundleId) else {
            status = .notRunning
            scheduleConnectionAttempt()
            return
        }

        // Check whether user approved integration with DuckDuckGo in Bitwarden
        guard installationService.isIntegrationWithDuckDuckGoEnabled else {
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
            os_log("BWManagement: Running of proxy process failed", type: .error)
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

            self?.connectToBitwardenProcess()
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
            self?.sendStatus()
        }
    }

    private func stopStatusRefreshing() {
        statusRefreshingTimer?.invalidate()
        statusRefreshingTimer = nil
    }

    // MARK: - Handling Incoming Messages

    private func handleCommand(_ command: BWCommand) {
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
                      encryption.setSharedKey(sharedKeyData) else {
                    status = .error(error: .injectingOfSharedKeyFailed)
                    return
                }
                status = .waitingForStatusResponse

                verifyBitwardenIsResponding()
                sendStatus()
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
            logOrAssertionFailure("BWManager: Wrong handler")
        }
    }

    private var verificationTimer: Timer?

    private func verifyBitwardenIsResponding() {
        verificationTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] timer in
            self?.verificationTimer?.invalidate()
            self?.verificationTimer = nil

            if (self?.status == .waitingForStatusResponse) {
                BWNotRespondingAlert.show()
            }
        }
    }

    private func handleError(_ error: String, blocking: Bool) {
        let bitwardenError: BWError
        switch error {
        case "cannot-decrypt":
            logOrAssertionFailure("BWManagement: Bitwarden error - cannot decrypt")
            bitwardenError = .bitwardenCannotDecrypt
        case "locked":
            if case let .connected(vault) = status {
                status = .connected(vault: vault.locked)
            } else {
                sendStatus()
            }
            return
        default: logOrAssertionFailure("BWManager: Unhandled error")
            bitwardenError = .bitwardenRespondedWithError
        }

        if blocking {
            status = .error(error: bitwardenError)
        }
    }

    private func handleHandshakeResponse(encryptedSharedKey: String, status: String) {
        guard status == "success" else {
            self.status = .error(error: .handshakeFailed)
            cancelConnectionAndScheduleNextAttempt()
            return
        }

        guard let sharedKey = encryption.decryptSharedKey(encryptedSharedKey) else {
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

    private func handleEncryptedResponse(_ encryptedPayload: BWResponse.EncryptedPayload, messageId: MessageId) {
        guard let dataString = encryptedPayload.data,
              let data = Data(base64Encoded: dataString),
              let ivDataString = encryptedPayload.iv,
              let ivData = Data(base64Encoded: ivDataString),
              let hmacString = encryptedPayload.mac,
              let hmac = Data(base64Encoded: hmacString)
        else {
            status = .error(error: .parsingFailed)
            return
        }

        // Compare HMAC
        let ourHmac = encryption.computeHmac(data, iv: ivData)
        guard ourHmac == hmac else {
            logOrAssertionFailure("BWManager: HMAC comparison failed")
            return
        }

        let decryptedData = encryption.decryptData(data, andIv:ivData)
        guard decryptedData.count > 0 else {
            status = .error(error: .decryptionOfDataFailed)
            return
        }

        guard let response = BWResponse(from: decryptedData) else {
            status = .error(error: .parsingFailed)
            return
        }

        switch response.command {
        case .status:
            if case let .array(payloadItemArray) = response.payload {
                handleStatusResponse(payloadItemArray: payloadItemArray)
                return
            }
        case .credentialRetrieval:
            if let payload = response.payload {
                handleCredentialRetrievalResponse(messageId: messageId, payload: payload)
                return
            }
        case .credentialCreate:
            if case let .item(payloadIdem) = response.payload {
                handleCredentialCreationResponse(messageId: messageId, payloadItem: payloadIdem)
                return
            }
        case .credentialUpdate:
            if case let .item(payloadIdem) = response.payload {
                handleCredentialUpdateResponse(messageId: messageId, payloadItem: payloadIdem)
                return
            }

        default: break
        }

        logOrAssertionFailure("BWManager: Unhandled response")
    }

    private func handleStatusResponse(payloadItemArray: [BWResponse.PayloadItem]) {
        // Find the active vault
        guard let activePayloadItem = payloadItemArray.filter({ $0.active ?? false }).first else {
            status = .error(error: .noActiveVault)
            return
        }

        refreshStatus(payloadItem: activePayloadItem)
    }

    private func handleCredentialRetrievalResponse(messageId: MessageId, payload: BWResponse.Payload) {
        guard let completion = retrieveCredentialsCompletionCache[messageId] else {
            logOrAssertionFailure("BWManager: Missing or already removed completion block")
            return
        }

        switch payload {
        case .array(let payloadItemArray):
            let credentials = payloadItemArray.compactMap { BWCredential(from: $0) }
            retrieveCredentialsCompletionCache[messageId] = nil
            completion(credentials, nil)
        case .item(let payloadItem):
            guard let error = payloadItem.error else {
                logOrAssertionFailure("BWManager: Unexpected response in credential retrieval")
                return
            }

            handleError(error, blocking: false)
            completion([], BWError.credentialRetrievalFailed)
        }
    }

    private func handleCredentialCreationResponse(messageId: MessageId, payloadItem: BWResponse.PayloadItem) {

        guard let completion = createCredentialCompletionCache[messageId] else {
            logOrAssertionFailure("BWManager: Missing completion block")
            return
        }
        createCredentialCompletionCache[messageId] = nil

        if payloadItem.status == "success" {
            completion(nil)
        } else {
            completion(BWError.credentialCreationFailed)
        }
    }

    private func handleCredentialUpdateResponse(messageId: MessageId, payloadItem: BWResponse.PayloadItem) {

        guard let completion = updateCredentialCompletionCache[messageId] else {
            logOrAssertionFailure("BWManager: Missing completion block")
            return
        }
        updateCredentialCompletionCache[messageId] = nil

        if payloadItem.status == "success" {
            completion(nil)
        } else {
            completion(BWError.credentialUpdateFailed)
        }
    }

    // MARK: - Sending Messages

    lazy var messageIdGenerator = BWMessageIdGenerator()

    func sendHandshake() {
        guard let publicKey = generateKeyPair() else {
            logOrAssertionFailure("BWManager: Public key is missing")
            return
        }

        guard let messageData = BWRequest.makeHandshakeRequest(with: publicKey,
                                                                      messageId: messageIdGenerator.generateMessageId()).data else {
            logOrAssertionFailure("BWManager: Making the handshake message failed")
            return
        }

        communicator.send(messageData: messageData)
    }

    private func sendStatus() {
        guard let commandData = BWRequest.EncryptedCommand(command: .status, payload: nil).data,
              let encryptedCommand = encryptCommandData(commandData),
              let messageData = BWRequest.makeEncryptedCommandRequest(encryptedCommand: encryptedCommand,
                                                                      messageId: messageIdGenerator.generateMessageId()).data else {
            logOrAssertionFailure("BWManager: Making the status message failed")
            status = .error(error: .sendingOfStatusMessageFailed)
            return
        }

        communicator.send(messageData: messageData)
    }

    private func sendCredentialRetrieval(url: URL, messageId: MessageId) {
        let payload = BWRequest.EncryptedCommand.Payload(uri: url.absoluteString)
        guard let commandData = BWRequest.EncryptedCommand(command: .credentialRetrieval,
                                                                  payload: payload).data,
              let encryptedCommand = encryptCommandData(commandData),
              let messageData = BWRequest.makeEncryptedCommandRequest(encryptedCommand: encryptedCommand,
                                                                      messageId: messageId).data else {
            logOrAssertionFailure("BWManager: Making the credential retrieval message failed")
            status = .error(error: .sendingOfStatusMessageFailed)
            return
        }

        communicator.send(messageData: messageData)
    }

    private func sendCredentialCreation(_ credential: BWCredential, messageId: MessageId) {
        let payload = BWRequest.EncryptedCommand.Payload(uri: credential.url,
                                                                userId: credential.userId,
                                                                userName: credential.username,
                                                                password: credential.password,
                                                                name: credential.credentialName)
        guard let commandData = BWRequest.EncryptedCommand(command: .credentialCreate,
                                                                  payload: payload).data,
              let encryptedCommand = encryptCommandData(commandData),
              let messageData = BWRequest.makeEncryptedCommandRequest(encryptedCommand: encryptedCommand,
                                                                      messageId: messageId).data else {
            logOrAssertionFailure("BWManager: Making the credential creation message failed")
            status = .error(error: .sendingOfStatusMessageFailed)
            return
        }

        communicator.send(messageData: messageData)
    }

    private func sendCredentialUpdate(_ credential: BWCredential, messageId: MessageId) {
        let payload = BWRequest.EncryptedCommand.Payload(uri: credential.url,
                                                                userId: credential.userId,
                                                                userName: credential.username,
                                                                password: credential.password,
                                                                name: credential.credentialName,
                                                                credentialId: credential.credentialId)
        guard let commandData = BWRequest.EncryptedCommand(command: .credentialUpdate,
                                                                  payload: payload).data,
              let encryptedCommand = encryptCommandData(commandData),
              let messageData = BWRequest.makeEncryptedCommandRequest(encryptedCommand: encryptedCommand,
                                                                      messageId: messageId).data else {
            logOrAssertionFailure("BWManager: Making the credential update message failed")
            status = .error(error: .sendingOfStatusMessageFailed)
            return
        }

        communicator.send(messageData: messageData)
    }

    private func encryptCommandData(_ commandData: Data) -> String? {
        guard let encryptedData = encryption.encryptData(commandData) else {
            return nil
        }

#if DEBUG
        // Verify encryption
        let decryptedData = encryption.decryptData(encryptedData.data, andIv: encryptedData.iv)
        assert(decryptedData.utf8String() != nil)
#endif

        return "2.\(encryptedData.iv.base64EncodedString())|\(encryptedData.data.base64EncodedString())|\(encryptedData.hmac.base64EncodedString())"
    }
    
    // MARK: - Encryption

    lazy var encryption = BWEncryption()

    private func generateKeyPair() -> Base64EncodedString? {
        return encryption.generateKeys()
    }

    // MARK: - Shared Key Storage

    let keyStorage: BWKeyStoring = BWKeyStorage()

    // MARK: - Status

    @Published private(set) var status: BWStatus = .disabled {
        didSet {
            os_log("Status changed: %s", log: .bitwarden, type: .default, String(describing: status))

            // If vault is locked, keep refreshing the latest status
            if case .connected(vault: let vault) = status,
               vault.status == .locked {
                scheduleStatusRefreshing()
            } else {
                stopStatusRefreshing()
            }
            verificationTimer?.invalidate()
            verificationTimer = nil
        }
    }
    var statusPublisher: Published<BWStatus>.Publisher { $status }

    private func refreshStatus(payloadItem: BWResponse.PayloadItem) {
        guard let id = payloadItem.id,
              let email = payloadItem.email,
              let statusString = payloadItem.status,
              let status = BWVault.Status(rawValue: statusString) else {
            self.status = .error(error: .statusParsingFailed)
            return
        }

        let vault = BWVault(id: id, email: email, status: status, active: true)
        self.status = .connected(vault: vault)
    }

    func refreshStatusIfNeeded() {
        switch status {
        case .connected(vault: _), .error(error: _): sendStatus()
        default: return
        }
    }

    // MARK: - Cretentials

    var retrieveCredentialsCompletionCache = [MessageId: ([BWCredential], BWError?) -> Void]()

    func retrieveCredentials(for url: URL, completion: @escaping ([BWCredential], BWError?) -> Void) {
        let messageId = messageIdGenerator.generateMessageId()
        retrieveCredentialsCompletionCache[messageId] = completion
        sendCredentialRetrieval(url: url, messageId: messageId)
    }

    var createCredentialCompletionCache = [MessageId: ((BWError?) -> Void)]()

    func create(credential: BWCredential, completion: @escaping (BWError?) -> Void) {
        let messageId = messageIdGenerator.generateMessageId()
        createCredentialCompletionCache[messageId] = completion
        sendCredentialCreation(credential, messageId: messageId)
    }

    var updateCredentialCompletionCache = [MessageId: ((BWError?) -> Void)]()

    func update(credential: BWCredential, completion: @escaping (BWError?) -> Void) {
        let messageId = messageIdGenerator.generateMessageId()
        updateCredentialCompletionCache[messageId] = completion
        sendCredentialUpdate(credential, messageId: messageId)
    }

}

extension BWManager: BWCommunicatorDelegate {

    func bitwardenCommunicatorProcessDidTerminate(_ bitwardenCommunicator: BWCommunication) {
        guard isBitwardenPasswordManager else {
            return
        }

        status = .notRunning

        scheduleConnectionAttempt()
    }


    func bitwardenCommunicator(_ bitwardenCommunicator: BWCommunication, didReceiveMessageData messageData: Data) {
        guard let response = BWResponse(from: messageData) else {
            logOrAssertionFailure("BWManager: Can't decode the message")
            return
        }

        if let command = response.command, command == .connected || command == .disconnected {
            handleCommand(command)
            return
        }

        guard let messageId = response.messageId, messageIdGenerator.verify(messageId: messageId) else {
            os_log("BWManager: Unkown message id. Ignoring the message", log: .bitwarden, type: .default)
            return
        }

        if case let .item(payloadItem) = response.payload {
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

        if let encryptedPayload = response.encryptedPayload, let messageId = response.messageId {
            handleEncryptedResponse(encryptedPayload, messageId: messageId)
            return
        }

        logOrAssertionFailure("BWManager: Unhandled message from Bitwarden")
    }
}
