//
//  HistoryViewPixel.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
import PixelKit

/**
 * This enum keeps pixels related to HTML History View.
 */
enum HistoryViewPixel: PixelKitEventV2 {

    /**
     * Event Trigger: History View is displayed to user.
     *
     * > Note: This is a daily pixel.
     *
     * > Related links:
     * [Privacy Triage TBD]()
     * [Detailed Pixels description](https://app.asana.com/0/0/1209364382402737/f)
     *
     * Anomaly Investigation:
     * - Anomaly in this pixel may mean an increase/drop in app use.
     */
    case historyPageShown

    // MARK: - Debug

    /**
     * Event Trigger: History View reports a JavaScript exception.
     *
     * > Note: This is a daily + standard pixel.
     *
     * > Related links:
     * [Privacy Triage TBD]()
     * [Detailed Pixels description](https://app.asana.com/0/0/1209364382402737/f)
     *
     * Anomaly Investigation:
     * - Anomaly in this pixel may mean a critical breakage in the History View.
     */
    case historyPageExceptionReported(message: String)

    var name: String {
        switch self {
        case .historyPageShown: return "history-page_shown"
        case .historyPageExceptionReported: return "history-page_exception-reported"
        }
    }

    var parameters: [String: String]? {
        switch self {
        case .historyPageShown:
            return nil
        case .historyPageExceptionReported(let message):
            return [PixelKit.Parameters.assertionMessage: message]
        }
    }

    var error: (any Error)? {
        nil
    }
}
