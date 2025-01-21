//
//  NativeMessagingCommunicator.swift
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

import Common
import Foundation
import os.log

protocol NativeMessagingCommunicatorDelegate: AnyObject {

    func nativeMessagingCommunicator(_ nativeMessagingCommunicator: NativeMessagingCommunication, didReceiveMessageData messageData: Data)
    func nativeMessagingCommunicatorProcessDidTerminate(_ nativeMessagingCommunicator: NativeMessagingCommunication)

}

protocol NativeMessagingCommunication {

    func runProxyProcess() throws
    func terminateProxyProcess()

    var delegate: NativeMessagingCommunicatorDelegate? { get set }
    func send(messageData: Data)

}

final class NativeMessagingCommunicator: NSObject, NativeMessagingCommunication {

    let appPath: String
    let arguments: [String]

    weak var delegate: NativeMessagingCommunicatorDelegate?

    // MARK: - Running Proxy Process

    private struct ProcessWrapper {
        let process: Process
        let readingHandle: FileHandle
        let writingHandle: FileHandle
    }

    private var process: ProcessWrapper?

    init(appPath: String, arguments: [String]) {
        self.appPath = appPath
        self.arguments = arguments
    }

    func runProxyProcess() throws {
        if process != nil {
            terminateProxyProcess()
        }

        let process = Process()

        let outputPipe = Pipe()
        let outHandle = outputPipe.fileHandleForReading
        outHandle.readabilityHandler = receiveData(_:)

        let inputPipe = Pipe()
        let inputHandle = inputPipe.fileHandleForWriting

        process.executableURL = URL(fileURLWithPath: appPath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardInput = inputPipe
        process.terminationHandler = processDidTerminate(_:)

        try process.run()
        Logger.webExtensions.log("NativeMessagingCommunicator: Proxy process running")

        self.process = ProcessWrapper(process: process, readingHandle: outHandle, writingHandle: inputHandle)
    }

    func terminateProxyProcess() {
        process?.process.terminate()
        process = nil
    }

    private func processDidTerminate(_ process: Process) {
        Logger.webExtensions.log("NativeMessagingCommunicator: Proxy process terminated")

        if let runningProcess = self.process?.process {
            if process != runningProcess {
                // Terminated to run another process
                return
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.nativeMessagingCommunicatorProcessDidTerminate(self)
        }
    }

    // MARK: - Sending Messages

    func send(messageData: Data) {
        write(messageData: messageData)
    }

    private func write(messageData: Data) {
        guard let process = process else {
            assertionFailure("Process not running")
            return
        }

        // Prefix with the length of data
        var messageDataCount = UInt32(messageData.count)
        let messagePrefix = Data(bytes: &messageDataCount, count: MemoryLayout.size(ofValue: messageDataCount))
        let finalMessage = messagePrefix + messageData

        process.writingHandle.write(finalMessage)
    }

    // MARK: - Receiving Messages

    private let realisticMessageLength = 200000
    private var accumulatedData = Data()
    private let dataQueue = DispatchQueue(label: "NativeMessagingCommunicator.queue")

    func receiveData(_ fileHandle: FileHandle) {
        let newData = fileHandle.availableData
        dataQueue.async {
            self.accumulatedData.append(newData)
            self.processAccumulatedData()
        }
    }

    private func processAccumulatedData() {
        dataQueue.async {
            repeat {
                let (messageData, remainingData) = self.readMessage(availableData: self.accumulatedData)
                self.accumulatedData = remainingData

                guard let messageData = messageData else {
                    return
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.delegate?.nativeMessagingCommunicator(self, didReceiveMessageData: messageData)
                }
            } while self.accumulatedData.count >= 2 /*EOF*/
        }
    }

    func readMessage(availableData: Data) -> (messageData: Data?, availableData: Data) {
        guard availableData.count > 0 else { return (nil, availableData: availableData) }

        // First 4 bytes of the message contain the message length
        let dataPrefix = availableData.prefix(4)
        guard dataPrefix.count == 4 else {
            assertionFailure("Wrong format of the message")
            return (nil, availableData)
        }

        let dataPrefixArray = [UInt8](dataPrefix)
        let messageLength = fromByteArray(dataPrefixArray, UInt32.self)

        let dataPostfix = availableData.dropFirst(4)

        if messageLength > dataPostfix.count {
            if messageLength > realisticMessageLength {
                self.accumulatedData = Data()
                return (nil, Data())
            }
            return (nil, availableData)
        }

        let messageData = dataPostfix.prefix(Int(messageLength))
        let availableData = dataPostfix.dropFirst(Int(messageLength))
        return (messageData: messageData, availableData: availableData)
    }

    private func fromByteArray<T>(_ value: [UInt8], _: T.Type) -> T {
        return value.withUnsafeBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: T.self, capacity: 1) {
                $0.pointee
            }
        }
    }

}
