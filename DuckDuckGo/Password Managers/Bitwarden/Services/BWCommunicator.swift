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

@objc protocol BWCommunicationXPC {
    func runProxyProcess(errorHandler: ((Error) -> Void)?)
    func terminateProxyProcess()
    func send(messageData: Data)
    var processDidReceiveMessage: ((Data) -> Void)? { get set }
}

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
