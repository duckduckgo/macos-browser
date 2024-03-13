//
//  HistoryTabExtensionTests.swift
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

import BrowserServicesKit
import Combine
import Navigation
import WebKit
import XCTest

@testable import DuckDuckGo_Privacy_Browser

class HistoryTabExtensionTests: XCTestCase {

    @MainActor
    func testWhenBurnerTab_ThenNoHistoryIsStored() {
        let historyCoordinatingMock = HistoryCoordinatingMock()

        let trackersPublisher: AnyPublisher<DetectedTracker, Never> = Empty().eraseToAnyPublisher()
        let urlPublisher: AnyPublisher<URL?, Never> = Empty().eraseToAnyPublisher()
        let titlePublisher: AnyPublisher<String?, Never> = Empty().eraseToAnyPublisher()
        let historyTabExtension = HistoryTabExtension(isBurner: true, historyCoordinating: historyCoordinatingMock, trackersPublisher: trackersPublisher, urlPublisher: urlPublisher, titlePublisher: titlePublisher)

        let navigationIdentity = NavigationIdentity(nil)
        let responderChain = ResponderChain(responderRefs: [])
        let urlRequest = URLRequest(url: .duckDuckGo)
        let frameInfo = FrameInfo(frame: WKFrameInfo())
        let navigationAction = NavigationAction(request: urlRequest, navigationType: .reload, currentHistoryItemIdentity: nil, redirectHistory: [], isUserInitiated: false, sourceFrame: frameInfo, targetFrame: nil, shouldDownload: false, mainFrameNavigation: nil)
        let navigation = Navigation(identity: navigationIdentity, responders: responderChain, state: .started, redirectHistory: [navigationAction], isCurrent: true, isCommitted: false)
        historyTabExtension.willStart(navigation)
        historyTabExtension.didCommit(navigation)

        XCTAssertFalse(historyCoordinatingMock.addVisitCalled)
        XCTAssertFalse(historyCoordinatingMock.updateTitleIfNeededCalled)
        XCTAssertFalse(historyCoordinatingMock.commitChangesCalled)
    }

}
