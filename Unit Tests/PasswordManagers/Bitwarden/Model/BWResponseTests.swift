//
//  BWResponseTests.swift
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
import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class BWResponseTests: XCTestCase {

    func testParsingOfConnectedMessage() {
        let data = "{\"command\":\"connected\"}".data(using: .utf8)
        let response = BWResponse(from: data!)!
        XCTAssertEqual(response.command, .connected)
    }

    func testParsingOfDisconnectedMessage() {
        let data = "{\"command\":\"disconnected\"}".data(using: .utf8)
        let response = BWResponse(from: data!)!
        XCTAssertEqual(response.command, .disconnected)
    }

    func testParsingOfHandshakeMessage() {
        let messageId = "6A474111-47C9-4772-AAA5-05EF531F7AA1"
        let version = "1"
        let status = "success"
        let sharedKey = "LrAZO3ZTVuhJZsqMmGnU4ZcNMxqbznRxkuVKjNou9+frmfGh0WQbltmzj8JFvT1Or4TfOH/E7bm4ROwns1y0FdiL/CJMSzK4idALpzINLn5jMqOqhdebNuZjb1F+f3OP6trMheMw/WQZdiWLxGCyB/BCZohyQJjRm4HfZhnH1Hg91hE+YnqnPpDMASlAKhziUFsGjFSKEoXhbOWrTawFTv35zrt1T6LrZ7uclH9KISZvxth1iP0JJOT+UhzwXpd8Vy9qWhIX8jidM33UgAhUpfza8iHsoiA79PIjLFGdxh+n81NlFV/4QnqM/UGoxO8usgFUA9Twf7GiaKU3dPRWgg=="
        let data = "{\"messageId\":\"\(messageId)\",\"version\":\(version),\"payload\":{\"status\":\"\(status)\",\"sharedKey\":\"\(sharedKey)\"}}".data(using: .utf8)
        let response = BWResponse(from: data!)!
        XCTAssertEqual(response.messageId, messageId)
        XCTAssertEqual(String(response.version!), version)
        switch response.payload! {
        case .array: XCTFail("Not correct parsing")
        case .item(let payloadItem):
            XCTAssertEqual(payloadItem.status, status)
            XCTAssertEqual(payloadItem.sharedKey, sharedKey)
        }
    }

    func testParsingOfEncryptedMessage() {
        let messageId = "6335C225-F3C4-41C1-B552-64053180A522"
        let version = "1"
        let encryptedString = "2.AkPPQgg7Tki0oS/V0nFRXQ==|YvCVBhg64OJcT0+zFc/e04dG37rJvfspG3k7BhUtABLBQbvVEeDgpjwb8jm7xAI+Nm2qLHmOgxcaf3mw4DDlc76tEOLt06GPqyEfCGr0ob0YFIdtfNdB1ruLxMlC2SBjxqwMUTuebBXnGyO2/NPur/ZOmak4aBINcnIlLJXunN+ju/AH9pv37JDJAfWVvebN|8CIuGdiJ6w4KY7GxMT5YbyUCf5mW2bh45ZGRAno98rY="
        let encryptionType = "2"
        let data = "YvCVBhg64OJcT0+zFc/e04dG37rJvfspG3k7BhUtABLBQbvVEeDgpjwb8jm7xAI+Nm2qLHmOgxcaf3mw4DDlc76tEOLt06GPqyEfCGr0ob0YFIdtfNdB1ruLxMlC2SBjxqwMUTuebBXnGyO2/NPur/ZOmak4aBINcnIlLJXunN+ju/AH9pv37JDJAfWVvebN"
        let iv = "AkPPQgg7Tki0oS/V0nFRXQ=="
        let mac = "8CIuGdiJ6w4KY7GxMT5YbyUCf5mW2bh45ZGRAno98rY="
        let message = " {\"messageId\":\"\(messageId)\",\"version\":\(version),\"encryptedPayload\":{\"encryptedString\":\"\(encryptedString)\",\"encryptionType\":\(encryptionType),\"data\":\"\(data)\",\"iv\":\"\(iv)\",\"mac\":\"\(mac)\"}}".data(using: .utf8)
        let response = BWResponse(from: message!)!
        XCTAssertEqual(response.messageId, messageId)
        XCTAssertEqual(String(response.version!), version)
        XCTAssertEqual(response.messageId, messageId)
        XCTAssertEqual(response.encryptedPayload?.encryptedString, encryptedString)
        XCTAssertEqual(String(response.encryptedPayload!.encryptionType!), encryptionType)
        XCTAssertEqual(response.encryptedPayload?.data, data)
        XCTAssertEqual(response.encryptedPayload?.iv, iv)
        XCTAssertEqual(response.encryptedPayload?.mac, mac)
    }

    func testParsingOfDecryptedStatus() {
        let command = BWCommand.status
        let id = "200"
        let email = "email@duck.com"
        let status = "unlocked"
        let active = "true"
        let data = " {\"command\":\"\(command.rawValue)\",\"payload\":[{\"id\":\"\(id)\",\"email\":\"\(email)\",\"status\":\"\(status)\",\"active\":\(active)}]}".data(using: .utf8)
        let response = BWResponse(from: data!)!
        XCTAssertEqual(response.command, command)
        switch response.payload! {
        case .item: XCTFail("Not correct parsing")
        case .array(let payloadItemArray):
            XCTAssertEqual(payloadItemArray.count, 1)
            let payloadItem = payloadItemArray.first!
            XCTAssertEqual(payloadItem.id, id)
            XCTAssertEqual(payloadItem.email, email)
            XCTAssertEqual(payloadItem.status, status)
            XCTAssertEqual(String(payloadItem.active!), active)
        }
    }

    func testParsingOfDecryptedCredentialRetrieval() {
        let command = BWCommand.credentialRetrieval
        let userId = "877"
        let credentialId = "0fd7a152"
        let username = "username"
        let password = "123456"
        let name = "domain.com"
        let data = " {\"command\":\"\(command.rawValue)\",\"payload\":[{\"userId\":\"\(userId)\",\"credentialId\":\"\(credentialId)\",\"userName\":\"\(username)\",\"password\":\"\(password)\",\"name\":\"\(name)\"}]}".data(using: .utf8)
        let response = BWResponse(from: data!)!
        XCTAssertEqual(response.command, command)
        switch response.payload! {
        case .item: XCTFail("Not correct parsing")
        case .array(let payloadItemArray):
            XCTAssertEqual(payloadItemArray.count, 1)
            let payloadItem = payloadItemArray.first!
            XCTAssertEqual(payloadItem.userId, userId)
            XCTAssertEqual(payloadItem.credentialId, credentialId)
            XCTAssertEqual(payloadItem.userName, username)
            XCTAssertEqual(payloadItem.password, password)
            XCTAssertEqual(payloadItem.name, name)
        }
    }

    func testParsingOfCredentialCreate() {
        let command = BWCommand.credentialCreate
        let status = "success"
        let data = "{\"command\":\"\(command.rawValue)\",\"payload\":{\"status\":\"\(status)\"}}".data(using: .utf8)
        let response = BWResponse(from: data!)!
        XCTAssertEqual(response.command, command)
        switch response.payload! {
        case .array: XCTFail("Not correct parsing")
        case .item(let payloadItem):
            XCTAssertEqual(payloadItem.status, status)
        }
    }

    func testParsingOfCredentialUpdate() {
        let command = BWCommand.credentialUpdate
        let status = "success"
        let data = "{\"command\":\"\(command.rawValue)\",\"payload\":{\"status\":\"\(status)\"}}".data(using: .utf8)
        let response = BWResponse(from: data!)!
        XCTAssertEqual(response.command, command)
        switch response.payload! {
        case .array: XCTFail("Not correct parsing")
        case .item(let payloadItem):
            XCTAssertEqual(payloadItem.status, status)
        }
    }

}
