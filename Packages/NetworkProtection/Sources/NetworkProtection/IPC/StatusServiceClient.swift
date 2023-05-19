//
//  StatusServiceClient.swift
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
import os.log

enum StatusServiceQuery: String, Codable {
    case getTunnelStatus
}

public protocol StatusServiceClient {
    func tunnelStatus() throws -> ConnectionStatus
}

public class DefaultStatusServiceClient: StatusServiceClient {
    public enum QueryError: Error {
        case couldNotSendData(query: String, internalError: Error)
        case noResponse(query: String, result: IPCThroughCFMessagePort.MessageResult)
        case noDataInResponse(query: String)
        case couldNotDecodeResponse(query: String, error: Error)
    }

    private let ipcClient: IPCThroughCFMessagePort.Client
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    public init(ipcClient: IPCThroughCFMessagePort.Client? = nil) {
        self.ipcClient = ipcClient ?? IPCThroughCFMessagePort.Client()
    }

    public func tunnelStatus() throws -> ConnectionStatus {
        let query = StatusServiceQuery.getTunnelStatus
        let queryData = try jsonEncoder.encode(query)
        let result: IPCThroughCFMessagePort.MessageResult

        do {
            result = try ipcClient.send(queryData)
        } catch {
            throw QueryError.couldNotSendData(query: query.rawValue, internalError: error)
        }

        guard case .success(_, let response) = result else {
            throw QueryError.noResponse(query: query.rawValue, result: result)
        }

        guard let data = response else {
            throw QueryError.noDataInResponse(query: query.rawValue)
        }

        let connectionStatus: ConnectionStatus

        do {
            connectionStatus = try jsonDecoder.decode(ConnectionStatus.self, from: data)
        } catch {
            throw QueryError.couldNotDecodeResponse(query: query.rawValue, error: error)
        }

        return connectionStatus
    }
}
