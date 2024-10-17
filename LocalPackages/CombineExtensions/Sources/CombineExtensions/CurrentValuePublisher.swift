// The Swift Programming Language
// https://docs.swift.org/swift-book

import Combine
import Foundation

public final class CurrentValuePublisher<Output, Failure: Error> {

    private(set) public var value: Output
    private let wrappedPublisher: AnyPublisher<Output, Failure>
    private var cancellable: AnyCancellable?

    public init(initialValue: Output, publisher: AnyPublisher<Output, Failure>) {
        value = initialValue
        wrappedPublisher = publisher

        subscribeToPublisherUpdates()
    }

    private func subscribeToPublisherUpdates() {
        cancellable = wrappedPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }) { [weak self] value in
                self?.value = value
            }
    }
}

extension CurrentValuePublisher: Publisher {
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {

        wrappedPublisher.receive(subscriber: subscriber)
    }
    

}
