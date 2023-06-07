// The Swift Programming Language
// https://docs.swift.org/swift-book

#if swift(>=5.9)
@attached(member, names: named(Dependencies), named(DynamicDependencies), named(DependencyProvider), named(DynamicDependencyProvider), named(dependencyProvider), named(_currentDependencies), named(getAllDependencyProviderKeyPaths(from:)), named(makeDependencies), named(make), named(testFunc))
@attached(peer, names: suffixed(_DependencyProvider), suffixed(_DependencyProvider_allKeyPaths), suffixed(_DynamicDependencyProvider))
public macro Injectable() = #externalMacro(module: "DependencyInjectionMacros", type: "InjectableMacro")
#endif

/// helper struct used for resolving the dependencies
@dynamicMemberLookup
public struct MutableDynamicDependencies<Root> {

    var storagePtr: UnsafeMutablePointer<[AnyKeyPath: Any]>

    public init(_ storagePtr: UnsafeMutablePointer<[AnyKeyPath: Any]>) {
        self.storagePtr = storagePtr
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<Root, T>) -> T {
        get {
            self.storagePtr.pointee[keyPath] as! T // swiftlint:disable:this force_cast
        }
        nonmutating set {
            self.storagePtr.pointee[keyPath] = newValue
        }
    }

}
