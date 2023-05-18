//
//  IPCThroughCFMessagePortServer.swift
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
import Common

public protocol IPCThroughCFMessagePortServerDelegate: AnyObject {
    func handleMessage(_ data: Data) throws -> Data
}

extension IPCThroughCFMessagePort {

    public final class Server {
        private let portName: String
        private var isRunning = false

        private let encoder = JSONEncoder()
        private let decoder = JSONDecoder()

        weak var delegate: IPCThroughCFMessagePortServerDelegate?

        private lazy var messagePort: CFMessagePort = {
            var context = CFMessagePortContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)

            let callBack: CFMessagePortCallBack = { port, messageID, data, info in
                guard let port = port,
                      let data = data else {
                    return nil
                }

                let server = Unmanaged<Server>.fromOpaque(info!).takeUnretainedValue()
                return server.handleMessage(port: port, messageID: messageID, data: data)
            }

            return CFMessagePortCreateLocal(nil, portName as CFString, callBack, &context, nil)
        }()

        public init(portName: String = IPCThroughCFMessagePort.defaultMessagePort) {
            self.portName = portName
        }

        deinit {
            CFMessagePortInvalidate(messagePort)
        }

        public func startServer() {
            guard !isRunning else {
                return
            }

            isRunning = true
            let source = CFMessagePortCreateRunLoopSource(nil, messagePort, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        private func handleMessage(port: CFMessagePort, messageID: Int32, data: CFData) -> Unmanaged<CFData>? {
            guard let delegate = delegate else {
                return nil
            }

            do {
                let response = try delegate.handleMessage(data as Data)
                return Unmanaged.passRetained(response as CFData)
            } catch {

            }

            let message = String(data: data as Data, encoding: .utf8) ?? ""
            let responseString = "Message received"

            guard let responseData = responseString.data(using: .utf8) else {
                return nil
            }

            return Unmanaged.passRetained(responseData as CFData)
        }
    }
}
