//
//  WebViewSnapshotRenderer.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import WebKit
import os.log

protocol WebViewSnapshotRendering {

    @MainActor
    func renderSnapshot(webView: WKWebView) async -> NSImage?

}

final class WebViewSnapshotRenderer: WebViewSnapshotRendering {

    @MainActor
    func renderSnapshot(webView: WKWebView) async -> NSImage? {
        dispatchPrecondition(condition: .onQueue(.main))
        Logger.tabSnapshots.debug("Preview rendering started for \(String(describing: webView.url))")

        let configuration = WKSnapshotConfiguration.makePreviewSnapshotConfiguration()

        do {
            let image = try await webView.takeSnapshot(configuration: configuration)
            Logger.tabSnapshots.debug("Preview rendered for \(String(describing: webView.url))")

            return image
        } catch {
            Logger.tabSnapshots.error("Failed to render snapshot for \(String(describing: webView.url))")
            return nil
        }
    }

}

fileprivate extension WKSnapshotConfiguration {

    static func makePreviewSnapshotConfiguration() -> WKSnapshotConfiguration {
        let configuration = WKSnapshotConfiguration()
        configuration.snapshotWidth = NSNumber(floatLiteral: TabPreviewWindowController.width)
        return configuration
    }

}
