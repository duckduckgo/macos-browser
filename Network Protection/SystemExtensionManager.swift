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
import SystemExtensions

final actor SystemExtensionManager: NSObject {
    enum RequestResult {
        case activated
        case willActivateAfterReboot
    }

    final class RequestDelegate: NSObject, OSSystemExtensionRequestDelegate {
        private let waitingForUserApprovalHandler: () -> Void
        private let completionHandler: (RequestDelegate, Result<RequestResult, Error>) -> Void

        init(waitingForUserApprovalHandler: @escaping () -> Void, completionHandler: @escaping (RequestDelegate, Result<RequestResult, Error>) -> Void) {
            self.waitingForUserApprovalHandler = waitingForUserApprovalHandler
            self.completionHandler = completionHandler
        }

        func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {

            return .replace
        }

        func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
            waitingForUserApprovalHandler()
        }

        func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
            switch result {
            case .completed:
                completionHandler(self, .success(.activated))
            case .willCompleteAfterReboot:
                completionHandler(self, .success(.willActivateAfterReboot))
            @unknown default:
                // Not much we can do about this, so let's assume it's a good result and not show any errors
                completionHandler(self, .success(.activated))
                Pixel.fire(.networkProtectionSystemExtensionUnknownActivationResult)
            }
        }

        func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
            completionHandler(self, .failure(error))
        }
    }

    static let shared = SystemExtensionManager()

    private var bundleID: String {
        NetworkProtectionBundle.extensionBundle().bundleIdentifier!
    }

    private var requests = Set<RequestDelegate>()

    func activate(waitingForUserApprovalHandler: @Sendable @escaping () -> Void) async throws -> RequestResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RequestResult, Error>) in
            let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: bundleID, queue: .main)

            let requestDelegate = RequestDelegate(waitingForUserApprovalHandler: waitingForUserApprovalHandler) { request, result in
                continuation.resume(with: result)

                // Intentionally retaining self until this closure is executed
                self.requests.remove(request)
            }
            activationRequest.delegate = requestDelegate

            requests.insert(requestDelegate)
            OSSystemExtensionManager.shared.submitRequest(activationRequest)
        }
    }

    func deactivate(waitingForUserApprovalHandler: @Sendable @escaping () -> Void) async throws -> RequestResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RequestResult, Error>) in
            let activationRequest = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: bundleID, queue: .main)

            let requestDelegate = RequestDelegate(waitingForUserApprovalHandler: waitingForUserApprovalHandler) { request, result in
                continuation.resume(with: result)

                // Intentionally retaining self until this closure is executed
                self.requests.remove(request)
            }
            activationRequest.delegate = requestDelegate

            requests.insert(requestDelegate)
            OSSystemExtensionManager.shared.submitRequest(activationRequest)
        }
    }

}
