//
//  SystemExtensionManager.swift
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
import Cocoa
import Combine
@preconcurrency import SystemExtensions

struct SystemExtensionManager {

    enum RequestEvent {
        case waitingForUserApproval
        case activated
        case willActivateAfterReboot
    }

    let bundleID: String
    let manager: OSSystemExtensionManager

    init(bundleID: String = Bundle.main.networkProtectionExtensionBundleId,
         manager: OSSystemExtensionManager = .shared) {
        self.bundleID = bundleID
        self.manager = manager
    }

    func activate() -> AsyncThrowingStream<RequestEvent, Error> {
        return SystemExtensionRequest.activationRequest(forExtensionWithIdentifier: bundleID, manager: manager).submit()
    }

    func deactivate() async throws {
        for try await _ in SystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: bundleID, manager: manager).submit() {}
    }

}

final class SystemExtensionRequest: NSObject {

    typealias Event = SystemExtensionManager.RequestEvent

    private let request: OSSystemExtensionRequest
    private let manager: OSSystemExtensionManager

    private var continuation: AsyncThrowingStream<Event, Error>.Continuation?

    private init(request: OSSystemExtensionRequest, manager: OSSystemExtensionManager) {
        self.manager = manager
        self.request = request

        super.init()
    }

    static func activationRequest(forExtensionWithIdentifier bundleId: String, manager: OSSystemExtensionManager) -> Self {
        self.init(request: .activationRequest(forExtensionWithIdentifier: bundleId, queue: .global()), manager: manager)
    }

    static func deactivationRequest(forExtensionWithIdentifier bundleId: String, manager: OSSystemExtensionManager) -> Self {
        self.init(request: .deactivationRequest(forExtensionWithIdentifier: bundleId, queue: .global()), manager: manager)
    }

    /// submitting the request returns an Async Iterator providing the OSSystemExtensionRequest state change events
    /// until an `RequestEvent` event is received.
    func submit() -> AsyncThrowingStream<Event, Error> {
        assert(continuation == nil, "Request can only be submitted once")

        defer {
            request.delegate = self
            manager.submitRequest(request)
        }
        return AsyncThrowingStream { [self /* keep the request delegate alive */] continuation in
            continuation.onTermination = { _ in
                withExtendedLifetime(self) {}
            }
            self.continuation = continuation
        }
    }

}

extension SystemExtensionRequest: OSSystemExtensionRequestDelegate {

    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {

        return .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        continuation?.yield(.waitingForUserApproval)
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        switch result {
        case .completed:
            continuation?.yield(.activated)
        case .willCompleteAfterReboot:
            continuation?.yield(.willActivateAfterReboot)
        @unknown default:
            // Not much we can do about this, so let's assume it's a good result and not show any errors
            continuation?.yield(.activated)
            Pixel.fire(.networkProtectionSystemExtensionUnknownActivationResult)
        }

        continuation?.finish()
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        continuation?.finish(throwing: error)
    }

}
