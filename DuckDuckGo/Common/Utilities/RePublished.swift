//
//  RePublished.swift
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

/// `CurrentValueSubject` wrapper used to receive and store a published property and re-publish it when used as a $projectedValue
@propertyWrapper
struct RePublished<Owner: AnyObject, Value, Pub: Publisher<Value, Never>> {
    // swiftlint:disable opening_brace

    private enum State {
        case empty(getValue: (() -> Value), getPublisher: ((Owner) -> () -> Pub))
        case ready(subject: CurrentValueSubject<Value, Never>, cancellable: AnyCancellable)
    }
    private var state: State

    @available(*, unavailable, message: "@RePublished is only available on properties of classes")
    var wrappedValue: Value {
        fatalError()
    }
    static subscript(_enclosingInstance owner: Owner,
                     wrapped _: KeyPath<Owner, Value>,
                     storage selfKeyPath: ReferenceWritableKeyPath<Owner, Self>) -> Value {
        owner[keyPath: selfKeyPath].getSubject(withOwner: owner).value
    }

    @available(*, unavailable, message: "@RePublished is only available on properties of classes")
    var projectedValue: AnyPublisher<Value, Never> {
        fatalError()
    }
    static subscript(_enclosingInstance owner: Owner,
                     projected _: KeyPath<Owner, AnyPublisher<Value, Never>>,
                     storage selfKeyPath: ReferenceWritableKeyPath<Owner, Self>) -> AnyPublisher<Value, Never> {
        owner[keyPath: selfKeyPath].getSubject(withOwner: owner).eraseToAnyPublisher()
    }

    /** ```

     @RePublished<OwnerClass, ValueType> var varName1: ValueType

     init(publishedDependency: some Publisher<Value, Never>) {
         self._varName1 = RePublished(wrappedValue: someDefaultValue) {
             publishedDependency.map(\.someValue)
         }
     }

     @RePublished({ (self: OwnerClass) in self.model.$publishedProperty })
     var varName: ValueType = someDefaultValue

     ``` **/
    init(wrappedValue: @escaping @autoclosure () -> Value, _ getPublisher: @escaping (Owner) -> Pub) {
        self.init(wrappedValue: wrappedValue()) { owner in
            {
                getPublisher(owner)
            }
        }
    }

    /** ```

     @RePublished(OwnerClass.someValuePublisher)
     var varName: ValueType = someDefaultValue

     func someValuePublisher() -> some Publisher<ValueType, Never> {
         self.model.$publishedProperty.map(\.someProperty).filter { $0.isValid }
     }

     ``` **/
    init(wrappedValue: @escaping @autoclosure () -> Value, _ getPublisher: @escaping (Owner) -> () -> Pub) {
        self.state = .empty(getValue: wrappedValue, getPublisher: getPublisher)
    }

}
extension RePublished where Pub == AnyPublisher<Value, Never> {

    /** ```

     @RePublished(\OwnerClass.model.$publishedProperty)
     var varName1: ValueType = defaultValue

     ``` **/
    init(wrappedValue: @escaping @autoclosure () -> Value, _ publisherKeyPath: KeyPath<Owner, some Publisher<Value, Never>>) {
        self.init(wrappedValue: wrappedValue()) { (owner: Owner) in
            owner[keyPath: publisherKeyPath].eraseToAnyPublisher()
        }
    }

}
extension RePublished where Pub == AnyPublisher<Value, Never>, Value: OptionalProtocol {

    /** ```

     @RePublished(\OwnerClass.model.$optionalPublishedProperty)
     var varName1: Value? // no default value required

     ``` **/
    init(_ publisherKeyPath: KeyPath<Owner, some Publisher<Value, Never>>) {
        self.init(wrappedValue: .none, publisherKeyPath)
    }

}
extension RePublished where Value: OptionalProtocol {

    /** ```

     @RePublished({ (self: OwnerClass) in self.model.$publishedProperty })
     var optionalValue: Value? // no default value required

     ``` **/
    init(_ getPublisher: @escaping (Owner) -> Pub) {
        self.init(wrappedValue: .none, getPublisher)

    }

    /** ```

     @RePublished(OwnerClass.someValuePublisher)
     var optionalValue: Value? // no default value required

     func someValuePublisher() -> some Publisher<ValueType, Never> {
         self.model.$publishedProperty.map(\.someProperty).filter { $0.isValid }
     }

     ``` **/
    init(_ getPublisher: @escaping (Owner) -> () -> Pub) {
        self.init(wrappedValue: .none, getPublisher)
    }
}

extension RePublished {

    private mutating func getSubject(withOwner owner: Owner) -> CurrentValueSubject<Value, Never> {
        switch state {
        case .ready(subject: let subject, _):
            return subject

        case let .empty(getValue: getValue, getPublisher: getPublisher):
            // capture newly created Subject object in the closure
            var subject: CurrentValueSubject<Value, Never>?
            let cancellable = getPublisher(owner)().sink { [weak owner] value in
                if let subject {
                    // receiving value update
                    // send .objectWillChange if the owner conforms to ObservableObject
                    // i.e. publishes objectWillChange notifcation when @Published property changes
                    if let observableObject = owner as? any ObservableObject {
                        Self.sendObjectWillChange(to: observableObject)
                    }
                    subject.send(value)
                } else {
                    // initial value received synchronously
                    subject = CurrentValueSubject(value)
                }
            }
            if subject == nil {
                subject = CurrentValueSubject(getValue())
            }

            self.state = .ready(subject: subject!, cancellable: cancellable)
            return subject!
        }
    }

    private static func sendObjectWillChange(to observableObject: some ObservableObject) {
        (observableObject.objectWillChange as? ObservableObjectPublisher)?.send()
    }

}
