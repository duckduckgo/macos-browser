//
//  ModalSheetCancellable.swift
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
import Foundation

final class ModalSheetCancellable: Cancellable {
    private weak var ownerWindow: NSWindow?
    private weak var modalSheet: NSWindow?
    private let condition: (() -> Bool)
    private let cancellationHandler: (() -> Void)?
    private let returnCode: NSApplication.ModalResponse?

    init(ownerWindow: NSWindow,
         modalSheet: NSWindow?,
         returnCode: NSApplication.ModalResponse? = .abort,
         condition: @escaping @autoclosure () -> Bool,
         cancellationHandler: (() -> Void)? = nil) {
        self.ownerWindow = ownerWindow
        self.modalSheet = modalSheet
        self.returnCode = returnCode
        self.condition = condition
        self.cancellationHandler = cancellationHandler
        // cancel the request when dialog owning window is closed
        NotificationCenter.default.addObserver(self, selector: #selector(cancel), name: NSWindow.willCloseNotification, object: ownerWindow)
    }

    @objc func cancel() {
        guard let ownerWindow, let modalSheet,
              ownerWindow.sheets.contains(modalSheet),
              condition() == true
        else { return }

        DispatchQueue.main.async { [cancellationHandler, returnCode, weak ownerWindow, weak modalSheet] in
            guard let ownerWindow, let modalSheet,
                  ownerWindow.sheets.contains(modalSheet)
            else { return }

            if let returnCode = returnCode {
                ownerWindow.endSheet(modalSheet, returnCode: returnCode)
            } else {
                ownerWindow.endSheet(modalSheet)
            }

            cancellationHandler?()
        }
    }

    deinit {
        cancel()
    }

}
