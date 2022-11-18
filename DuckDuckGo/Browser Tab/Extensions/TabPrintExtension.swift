//
//  TabPrintExtension.swift
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

import Combine
import AppKit
import WebKit
import Foundation

protocol PrintOperationUI {
    var modalWindow: NSWindow? { get }
    @discardableResult
    func runModal(for window: NSWindow) -> NSApplication.ModalResponse
    func stopModal()
}

extension NSApplication: PrintOperationUI {}

final class TabPrintExtension {

    struct Dependencies {
        @Injected(default: NSApp) static var ui: PrintOperationUI
    }

    private var userScriptsCancellable: AnyCancellable?

    // To avoid webpages invoking the printHandler and overwhelming the browser, this property keeps track of the active
    // print operation and ignores incoming printHandler messages if one exists.
    private var modalWindow: NSWindow?
    private var activePrintOperation: NSPrintOperation?

    init(tab: Tab) {
        userScriptsCancellable = tab.userScriptsPublisher.sink { [weak self] userScripts in
            userScripts?.printingUserScript.delegate = self
        }
    }

    func print(using webView: WKWebView, frameHandle: Any? = nil) {
        guard activePrintOperation == nil else { return }

        guard let window = webView.window,
              let printOperation = webView.printOperation(for: frameHandle)
        else { return }

        self.activePrintOperation = printOperation

        if printOperation.view?.frame.isEmpty == true {
            printOperation.view?.frame = webView.bounds
        }

        self.modalWindow = window
        printOperation.runModal(for: window,
                                delegate: self,
                                didRun: #selector(printOperationDidRun(printOperation:success:contextInfo:)),
                                contextInfo: nil)
        Dependencies.ui.runModal(for: window)
    }

    @objc func printOperationDidRun(printOperation: NSPrintOperation,
                                    success: Bool,
                                    contextInfo: UnsafeMutableRawPointer?) {
        activePrintOperation = nil

        if Dependencies.ui.modalWindow === self.modalWindow {
            Dependencies.ui.stopModal()
            self.modalWindow = nil
        }
    }

}

extension TabPrintExtension: PrintingUserScriptDelegate {

    func printingUserScript(_ script: PrintingUserScript, didRequestPrintControllerFor webView: WKWebView) {
        self.print(using: webView)
    }

}

extension Tab {

    func print() {
        extensions.printing?.print(using: webView)
    }

}
