//
//  ConnectionStatusTransitionAwaiter.swift
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

import Combine
import Foundation

/// This class provides a mechanism to asynchronously await for a certain connection transition
/// to be fulfilled, while also specifying a timeout for the expectation.
///
/// This class is necessary because we've been seen issues in macOS where our network extension
/// reports several status updates that look like noise when starting or stopping the tunnel.
///
/// While this class does not resolve any underlying issues there may be, it does try to ensure a more
/// consistent UX for users, regardless of underlying issues.
///
public final class ConnectionStatusTransitionAwaiter {

    public enum TransitionError: Error {
        case timeout
    }

    /// The target status for a supported transition
    ///
    private enum TargetStatus {
        case connected
        case disconnected

        func sameStatus(as status: ConnectionStatus) -> Bool {
            if case .connected = status,
               self == .connected {

                return true
            } else if case .disconnected = status,
                      self == .disconnected {

                return true
            } else {
                return false
            }
        }

        func acceptsIntermediateStatus(_ status: ConnectionStatus) -> Bool {
            if case .connecting = status,
               self == .connected {

                return true
            } else if case .disconnecting = status,
                      self == .disconnected {
                return true
            } else {
                return false
            }
        }
    }

    private let statusSubject: CurrentValueSubject<ConnectionStatus, Never>
    private let transitionTimeout: DispatchQueue.SchedulerTimeType.Stride

    public init(statusSubject: CurrentValueSubject<ConnectionStatus, Never>, transitionTimeout: DispatchQueue.SchedulerTimeType.Stride) {

        self.statusSubject = statusSubject
        self.transitionTimeout = transitionTimeout
    }

    // MARK: - Supported transitions

    public func waitUntilConnectionStarted() async throws {
        try await waitUntilTargetStatus(.connected)
    }

    public func waitUntilConnectionStopped() async throws {
        try await waitUntilTargetStatus(.disconnected)
    }

    private func waitUntilTargetStatus(_ targetStatus: TargetStatus) async throws {
        while await !expect(targetStatus, within: transitionTimeout) {
            let currentStatus = statusSubject.value

            if targetStatus.sameStatus(as: currentStatus) {
                return
            }

            // Even if we didn't reach the target status, the transition may be in a status
            // that is acceptable (ie: the target status is "connected" and the current status
            // is "connecting" is a good thing, same for "disconnected" and "disconnecting").
            //
            // When this is the case we'll extend the allowed waiting time, as we want to make
            // sure the toggle stays locked until the OS updates to another state that lets the
            // toggle be unlocked.
            //
            if targetStatus.acceptsIntermediateStatus(currentStatus) {
                // We have a valid intermediate status, let's wait more
                continue
            }

            throw TransitionError.timeout
        }
    }

    // MARK: - Status expectation awaiting

    /// Starts waiting for a certain expected status within the specified timeout interval.
    ///
    /// - Parameters:
    ///     - status: the expected status
    ///     - timeout: the timeout interval
    ///
    /// - Returns: `true` if the expectation was met within the timeout interval, or
    ///     `false` if the expectation wasn't met.
    ///
    private func expect(_ status: TargetStatus, within timeout: DispatchQueue.SchedulerTimeType.Stride) async -> Bool {

        await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?

            cancellable = statusSubject
                .receive(on: DispatchQueue.main)
                .timeout(timeout, scheduler: DispatchQueue.main)
                .sink(receiveCompletion: { _ in
                    cancellable?.cancel()
                    continuation.resume(returning: false)
                }, receiveValue: { newStatus in
                    guard status.sameStatus(as: newStatus) else {
                        return
                    }

                    cancellable?.cancel()
                    continuation.resume(returning: true)
                })
        }
    }
}
