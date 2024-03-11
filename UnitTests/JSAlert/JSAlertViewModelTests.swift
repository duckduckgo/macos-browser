//
//  JSAlertViewModelTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class JSAlertViewModelTests: XCTestCase {

    func testIsCancelButtonHidden() {
        let params: [JSAlertQuery.TestParameters] = [
            .init(type: .testAlert(), result: true),
            .init(type: .testConfirm(), result: false),
            .init(type: .testTextInput(), result: false)
        ]
        for param in params {
            let viewModel = JSAlertViewModel(query: param.type)
            XCTAssertEqual(viewModel.isCancelButtonHidden, param.result, "Expected isCancelButtonHidden for \(param.type) to equal \(param.result)")
        }
    }

    func testIsTextFieldHidden() {
        let params: [JSAlertQuery.TestParameters] = [
            .init(type: .testAlert(), result: true),
            .init(type: .testConfirm(), result: true),
            .init(type: .testTextInput(), result: false)
        ]

        for param in params {
            let viewModel = JSAlertViewModel(query: param.type)
            XCTAssertEqual(viewModel.isTextFieldHidden, param.result, "Expected isTextFieldHidden for \(param.type) to equal \(param.result)")
        }
    }

    func testIsMessageTextViewHidden() {
        let params: [JSAlertQuery.TestParameters] = [
            .init(type: .testAlert(parameters: .testData(prompt: "adskdsadjsab")), result: false),
            .init(type: .testConfirm(parameters: .testData(prompt: "")), result: true),
            .init(type: .testConfirm(parameters: .testData(prompt: "a")), result: false)
        ]

        for param in params {
            let viewModel = JSAlertViewModel(query: param.type)
            XCTAssertEqual(viewModel.isMessageScrollViewHidden, param.result, "Expected isTextFieldHidden for \(param.type) to equal \(param.result)")
        }
    }

    func testTitleText() {
        let params: [JSAlertQuery.TestParameters] = [
            .init(type: .testAlert(parameters: .testData(domain: "duckduckgo.com")), result: UserText.alertTitle(from: "duckduckgo.com")),
            .init(type: .testConfirm(parameters: .testData(domain: "wikipedia.com")), result: UserText.alertTitle(from: "wikipedia.com")),
            .init(type: .testTextInput(parameters: .testData(domain: "example.com")), result: UserText.alertTitle(from: "example.com"))
        ]

        for param in params {
            let viewModel = JSAlertViewModel(query: param.type)
            XCTAssertEqual(viewModel.titleText, param.result, "Expected messageText for \(param.type) to equal \(param.result)")
        }
    }

    func testMessageText() {
        let params: [JSAlertQuery.TestParameters] = [
            .init(type: .testAlert(parameters: .testData(prompt: "This is a prompt")), result: "This is a prompt"),
            .init(type: .testConfirm(parameters: .testData(prompt: "This is another prompt")), result: "This is another prompt"),
            .init(type: .testTextInput(parameters: .testData(prompt: "Yet another prompt")), result: "Yet another prompt")
        ]

        for param in params {
            let viewModel = JSAlertViewModel(query: param.type)
            XCTAssertEqual(viewModel.messageText, param.result, "Expected messageText for \(param.type) to equal \(param.result)")
        }
    }

    func testTextFieldDefaultText() {
        let params: [JSAlertQuery.TestParameters] = [
            .init(type: .testAlert(parameters: .testData(defaultInputText: "")), result: ""),
            .init(type: .testConfirm(parameters: .testData(defaultInputText: nil)), result: ""),
            .init(type: .testTextInput(parameters: .testData(defaultInputText: "Input text")), result: "Input text")
        ]

        for param in params {
            let viewModel = JSAlertViewModel(query: param.type)
            XCTAssertEqual(viewModel.textFieldDefaultText, param.result, "Expected textFieldDefaultText for \(param.type) to equal \(param.result)")
        }
    }

    func testConfirmAlertDialog() {
        var wasCalled = false
        let query = JSAlertQuery.testAlert { _ in
            wasCalled = true
        }
        let viewModel = JSAlertViewModel(query: query)
        viewModel.confirm(text: "")
        XCTAssert(wasCalled, "Expected completion to be called")
    }

    func testConfirmConfirmDialog() {
        var didConfirm = false
        let anotherQuery = JSAlertQuery.testConfirm { result in
            didConfirm = (try? result.get()) ?? false
        }
        let anotherViewModel = JSAlertViewModel(query: anotherQuery)
        anotherViewModel.confirm(text: "")
        XCTAssert(didConfirm, "Expected didConfirm value to be true")
    }

    func testConfirmTextInputDialog() {
        var text: String? = ""
        let anotherQuery = JSAlertQuery.testTextInput { result in
            text = try? result.get()
        }
        let anotherViewModel = JSAlertViewModel(query: anotherQuery)

        let expectedText = "expected"
        anotherViewModel.confirm(text: expectedText)

        XCTAssertEqual(text, expectedText, "Expected text value to be \(expectedText)")
    }

    func testCancelAlertDialog() {
        var wasCalled = false
        let query = JSAlertQuery.testAlert { _ in
            wasCalled = true
        }
        let viewModel = JSAlertViewModel(query: query)
        viewModel.cancel()
        XCTAssert(wasCalled, "Expected completion to be called")
    }

    func testCancelConfirmDialog() {
        var didConfirm: Bool?
        let anotherQuery = JSAlertQuery.testConfirm { result in
            switch result {
            case .success(let completionResult): didConfirm = completionResult
            case .failure: break
            }
        }
        let anotherViewModel = JSAlertViewModel(query: anotherQuery)
        anotherViewModel.cancel()

        XCTAssertEqual(didConfirm, false)
    }

    func testCancelTextInputDialog() {
        var text: String? = ""
        let anotherQuery = JSAlertQuery.testTextInput { result in
            switch result {
            case .success(let string): text = string
            case .failure: break
            }
        }
        let anotherViewModel = JSAlertViewModel(query: anotherQuery)
        anotherViewModel.cancel()

        XCTAssertNil(text)
    }
}

fileprivate extension JSAlertParameters {
    static func testData(domain: String = "", prompt: String = "", defaultInputText: String? = nil) -> Self {
        JSAlertParameters(domain: domain, prompt: prompt, defaultInputText: defaultInputText)
    }
}

fileprivate extension JSAlertQuery {
    struct TestParameters<Result> {
        let type: JSAlertQuery
        let result: Result
    }

    static func testAlert(parameters: JSAlertParameters = .testData(), callback: @escaping AlertDialogRequest.Callback = { _ in }) -> Self {
        .alert(AlertDialogRequest(parameters, callback: callback))
    }

    static func testConfirm(parameters: JSAlertParameters = .testData(), callback: @escaping ConfirmDialogRequest.Callback = { _ in }) -> Self {
        .confirm(ConfirmDialogRequest(parameters, callback: callback))
    }

    static func testTextInput(parameters: JSAlertParameters = .testData(), callback: @escaping TextInputDialogRequest.Callback = { _ in }) -> Self {
        .textInput(TextInputDialogRequest(parameters, callback: callback))
    }
}
