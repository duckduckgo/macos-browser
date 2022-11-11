//
//  PrintingUserScript.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import BrowserServicesKit
import WebKit

public protocol PrintingUserScriptDelegate: AnyObject {

    func printingUserScriptDidRequestPrintController(_ script: PrintingUserScript)

}

// TODO: StaticUserScript?
public class PrintingUserScript: NSObject, UserScript {
    public var requiresRunInPageContentWorld: Bool {
        return true
    }

    public var source: String = """
(function() {
    window.print = function() {
        webkit.messageHandlers.printHandler.postMessage({});
    };
}) ();
"""

    // To avoid webpages invoking the printHandler and overwhelming the browser, this property keeps track of the active
    // print operation and ignores incoming printHandler messages if one exists.
    fileprivate var activePrintOperation: NSPrintOperation?

    public var injectionTime: WKUserScriptInjectionTime = .atDocumentStart
    public var forMainFrameOnly: Bool = false
    public var messageNames: [String] = ["printHandler"]

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let webView = message.webView else { return }
        self.print(using: webView)
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

        let selector = #selector(printOperationDidRun(printOperation:success:contextInfo:))
        printOperation.runModal(for: window, delegate: self, didRun: selector, contextInfo: nil)
        // TODO: UI dependency provider
        NSApp.runModal(for: window)
    }

    @objc func printOperationDidRun(printOperation: NSPrintOperation,
                                    success: Bool,
                                    contextInfo: UnsafeMutableRawPointer?) {
        activePrintOperation = nil
        // TODO: UI dependency provider
        if NSApp.modalWindow != nil {
            NSApp.stopModal()
        }
    }

}

extension Tab {
    func print() {
        userScripts?.printingUserScript.print(using: webView)
    }
}
