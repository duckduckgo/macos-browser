//
//  TransparentProxyControllerEventHandler.swift
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

import os
import PixelKit

public protocol TransparentProxyControllerEventHandling {
    func handle(event: TransparentProxyController.Event)
}

public final class TransparentProxyControllerEventHandler: TransparentProxyControllerEventHandling {

    private let logger: Logger
    private let pixelKit: PixelKit?

    public init(logger: Logger, pixelKit: PixelKit? = .shared) {
        self.logger = logger
        self.pixelKit = pixelKit
    }

    public func handle(event: TransparentProxyController.Event) {
        switch event {
        case .startAttempt(let step):
            pixelKit?.fire(step, frequency: .legacyDailyAndCount)

            switch step {
            case .prevented(let error):
                logger.log("🟣 Proxy controller start attempt prevented: \(error, privacy: .public)")

            case .begin:
                logger.log("🟡 Proxy controller start attempt began")

            case .success:
                logger.log("🟢 Proxy controller start succeeded")

            case .failure(let error):
                logger.log("🔴 Proxy controller start failed: \(error, privacy: .public)")
            }
        case .stopped:
            logger.log("🔴 Proxy controller stopped")
        }
    }
}
