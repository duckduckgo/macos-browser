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

extension Publisher {
    /// Stops the publisher after a certain time has passed.
    ///
    /// The difference with `timeout(_:tolerance:scheduler:)` is that receiving new values does not reset the timeout.
    ///
    func stopAfter<S>(_ interval: S.SchedulerTimeType.Stride, tolerance: S.SchedulerTimeType.Stride? = nil, scheduler: S, options: S.SchedulerOptions? = nil) -> AnyPublisher<Output, Failure> where S: Scheduler {
        prefix(untilOutputFrom: Just(()).delay(for: interval, tolerance: tolerance, scheduler: scheduler, options: nil))
            .eraseToAnyPublisher()
    }
}

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

    public enum TransitionError: LocalizedError {
        case timeout

        public var errorDescription: String? {
            switch self {
            case .timeout:
                return "The connection attempt timed out, please try again"
            }
        }
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

    private let statusObserver: ConnectionStatusObserver
    private let transitionTimeout: DispatchQueue.SchedulerTimeType.Stride

    public init(statusObserver: ConnectionStatusObserver, transitionTimeout: DispatchQueue.SchedulerTimeType.Stride) {

        self.statusObserver = statusObserver
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
            let currentStatus = statusObserver.publisher.value

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
            /*
            if targetStatus.acceptsIntermediateStatus(currentStatus) {
                // We have a valid intermediate status, let's wait more
                continue
            }*/

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

            // Apparently cancelling the subscription is not instantaneous, as I've
            // seen Xcode complain about the continuation being called more than once.
            // Because of this, I'm taking an approach where I can nil out the
            // continuation whenever it's called.
            var internalContinuation = Optional(continuation)

            cancellable = statusObserver.publisher
                .receive(on: DispatchQueue.main)
                .stopAfter(timeout, scheduler: DispatchQueue.main)
                .sink(receiveCompletion: { _ in
                    internalContinuation?.resume(returning: false)
                    internalContinuation = nil
                    cancellable?.cancel()
                }, receiveValue: { newStatus in
                    guard status.sameStatus(as: newStatus) else {
                        return
                    }

                    internalContinuation?.resume(returning: true)
                    internalContinuation = nil
                    cancellable?.cancel()
                })
        }
    }
}
