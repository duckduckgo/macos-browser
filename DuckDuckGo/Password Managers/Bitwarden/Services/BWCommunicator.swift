//
//  BWCommunicator.swift
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
import os.log

protocol BWCommunicatorDelegate: AnyObject {

    func bitwardenCommunicator(_ bitwardenCommunicator: BWCommunication,
                               didReceiveMessageData messageData: Data)
    func bitwardenCommunicatorProcessDidTerminate(_ bitwardenCommunicator: BWCommunication)

}

protocol BWCommunication {

    func runProxyProcess() throws
    func terminateProxyProcess()

    var delegate: BWCommunicatorDelegate? { get set }
    func send(messageData: Data)

}

final class BWCommunicator: BWCommunication {

    static let appPath = "/Applications/Bitwarden.app/Contents/MacOS/Bitwarden"

    weak var delegate: BWCommunicatorDelegate?

    // MARK: - Running Proxy Process

    private struct BitwardenProcess {
        let process: Process
        let readingHandle: FileHandle
        let writingHandle: FileHandle
    }

    private var process: BitwardenProcess?

    func runProxyProcess() throws {
        if process != nil {
            terminateProxyProcess()
        }

        let process = Process()

        let outputPipe = Pipe()
        let outHandle = outputPipe.fileHandleForReading
        outHandle.readabilityHandler = receiveData(_:)

        let errorPipe = Pipe()
        let errorHandle = errorPipe.fileHandleForReading
        errorHandle.readabilityHandler = receiveErrorData(_:)

        let inputPipe = Pipe()
        let inputHandle = inputPipe.fileHandleForWriting

        process.executableURL = URL(fileURLWithPath: Self.appPath)
        process.arguments = ["chrome-extension://bitwarden"]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = inputPipe
        process.terminationHandler = processDidTerminate(_:)

        try process.run()
        os_log("BWCommunicator: Proxy process running", log: .bitwarden, type: .default)

        self.process = BitwardenProcess(process: process, readingHandle: outHandle, writingHandle: inputHandle)
    }

    func terminateProxyProcess() {
        process?.process.terminate()
        process = nil
    }

    private func processDidTerminate(_ process: Process) {
        os_log("BWCommunicator: Proxy process terminated", log: .bitwarden, type: .default)

        if let runningProcess = self.process?.process {
            if process != runningProcess {
                // Terminated to run another process
                return
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.bitwardenCommunicatorProcessDidTerminate(self)
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

    func receiveData(_ fileHandle: FileHandle) {

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
            let messageData = dataPostfix.prefix(Int(messageLength))
            let availableData = dataPostfix.dropFirst(Int(messageLength))
            return (messageData: messageData, availableData: availableData)
        }

        var availableData = fileHandle.availableData
        repeat {
            let (messageData, nextAvailableData) = readMessage(availableData: availableData)
            availableData = nextAvailableData

            guard let messageData = messageData else {
                if availableData.count >= 2 {
                    assertionFailure("Wrong format of the message")
                }
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.delegate?.bitwardenCommunicator(self, didReceiveMessageData: messageData)
            }
        } while availableData.count >= 2 /*EOF*/
    }

    private func receiveErrorData(_ fileHandle: FileHandle) {
        // Stderr is too verbose. Uncomment if necessary
        // if let stderrOutput = String(data: fileHandle.availableData, encoding: .utf8) {
        //     os_log("Stderr output:\n %s", log: .bitwarden, type: .error, stderrOutput)
        // }
    }

    private func fromByteArray<T>(_ value: [UInt8], _: T.Type) -> T {
        return value.withUnsafeBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: T.self, capacity: 1) {
                $0.pointee
            }
        }
    }

}
