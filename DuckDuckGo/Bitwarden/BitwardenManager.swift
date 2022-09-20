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

protocol BitwardenManagement {

    var status: BitwardenStatus { get }
    var statusPublisher: Published<BitwardenStatus>.Publisher { get }

}

final class BitwardenManager {

    static let shared = BitwardenManager()

    //TODO get and subscribe to the setting for password manager

    var state: BitwardenStatus = .disabled

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

    private func disableAndScheduleNextAttempt() {
        // Kill the proxy process and schedule the next attempt
        communicator.enabled = false
        scheduleConnectionAttempt()
    }

    // MARK: - Messages

    private func handle(command: String) {
        switch command {
        case "connected":
            sendHandshake()
            return
        case "disconnected":
            // Bitwarden application isn't running || User didn't approve DuckDuckGo browser integration
            disableAndScheduleNextAttempt()
        default:
            assertionFailure("Unknown command")
        }
    }

    private func handleHandshakeResponce(sharedKey: String, status: String) {
        guard status == "success" else {
            disableAndScheduleNextAttempt()
            return
        }

        //TODO Decrypt the shared key
        //TODO Send status message
    }

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
        guard let messageData = BitwardenMessage.makeStatusMessage().data else {
            assertionFailure("Making the status message failed")
            return
        }
        communicator.send(messageData: messageData)
    }
    
    // MARK: - Keys

    let openSSLWrapper = OpenSSLWrapper()

    var publicKey: String?

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

        if let command = message.command {
            handle(command: command)
            return
        }

        if let sharedKey = message.payload?.sharedKey, let status = message.payload?.status {
            handleHandshakeResponce(sharedKey: sharedKey, status: status)
        }

        //TODO check id of received message
    }

}
