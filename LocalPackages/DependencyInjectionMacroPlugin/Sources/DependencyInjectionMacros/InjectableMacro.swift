//
//  InjectableMacro.swift
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

import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum CustomError: Error, CustomStringConvertible {
    case message(String)

    case noInit(location: AbstractSourceLocation?)
    case noAttribute(AttributeSyntax, location: AbstractSourceLocation?)
    case noInjectedMembers(location: AbstractSourceLocation?)

    var description: String {
        switch self {
        case .message(let text):
            return text
        case .noInit(location: let location):
            return "\(location?.description ?? ""): error: Injectable should have an explicit init"
        case .noAttribute(let attribute, location: let location):
            return "\(location?.description ?? ""): error: init should have \(attribute.description)"
        case .noInjectedMembers(location: let location):
            return "\(location?.description ?? ""): error: @Injectable declaration has no @Injected or InjectedDependencies definitions"
        }
    }
}

extension AbstractSourceLocation: CustomStringConvertible {
    public var description: String {
        let line = line.description
        let col = column.description
        let file = file.description.dropping(prefix: "\"").dropping(suffix: "\"")
        return "\(file):\(line):\(col)"
    }
}

protocol TypeDeclSyntax: SyntaxProtocol {
    var identifier: TokenSyntax { get }

    var isTypealias: Bool { get }
    var isStruct: Bool { get }
    var isClass: Bool { get }
    var isActor: Bool { get }
    var isEnum: Bool { get }
}

protocol TypeDeclWithMemberBlockSyntax: TypeDeclSyntax {
    var memberBlock: MemberDeclBlockSyntax { get }
}

protocol InjectableDeclSyntax: TypeDeclWithMemberBlockSyntax {
}

extension TypeDeclSyntax {
    var isTypealias: Bool { false }
    var isStruct: Bool { false }
    var isClass: Bool { false }
    var isActor: Bool { false }
    var isEnum: Bool { false }
}

extension TypealiasDeclSyntax: TypeDeclSyntax {
    var isTypealias: Bool { true }
}
extension EnumDeclSyntax: TypeDeclSyntax {
    var isEnum: Bool { true }
}
extension StructDeclSyntax: InjectableDeclSyntax {
    var isStruct: Bool { true }
}
extension ClassDeclSyntax: InjectableDeclSyntax {
    var isClass: Bool { true }
}
extension ActorDeclSyntax: InjectableDeclSyntax {
    var isActor: Bool { true }
}

extension SyntaxProtocol {

    func asTypeDeclSyntax() -> TypeDeclSyntax? {
        if let declaration = self.asInjectableDeclSyntax() {
            return declaration
        } else if let declaration = self.as(EnumDeclSyntax.self) {
            return declaration
        } else {
            return nil
        }
    }

    func asInjectableDeclSyntax() -> InjectableDeclSyntax? {
        if let declaration = self.as(StructDeclSyntax.self) {
            return declaration
        } else if let declaration = self.as(ClassDeclSyntax.self) {
            return declaration
        } else if let declaration = self.as(ActorDeclSyntax.self) {
            return declaration
        } else {
            return nil
        }
    }

}

extension SyntaxProtocol {

    func getMemberBlock() -> MemberDeclBlockSyntax? {
        if let declaration = self.as(StructDeclSyntax.self) {
            return declaration.memberBlock
        } else if let declaration = self.as(ClassDeclSyntax.self) {
            return declaration.memberBlock
        } else if let declaration = self.as(ActorDeclSyntax.self) {
            return declaration.memberBlock
        } else {
            return nil
        }
    }

}

public struct InjectableMacro: MemberMacro {

    static func deprecatedAttribute(for identifier: String) -> AttributeSyntax {
        "@available(*, deprecated, message: \"use \(raw: identifier).make\")"
    }

    static func injectedVars(of declaration: InjectableDeclSyntax) -> [VariableDeclSyntax] {
        declaration.memberBlock.members.compactMap {
            guard let decl = $0.decl.as(VariableDeclSyntax.self),
                  decl.attributes?.first(where: { $0.as(AttributeSyntax.self)!.attributeName.as(SimpleTypeIdentifierSyntax.self)!.name.text == "Injected" }) != nil else { return nil }
            return decl
        }
    }

    // Add members to Injectable
    // swiftlint:disable:next function_body_length
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        guard let declaration = declaration.asInjectableDeclSyntax() else {
            throw CustomError.message("@Injectable only applicable for classes, structs and actors")
        }
        let identifier = declaration.identifier.text

        let injectedDependenciesTypealias = declaration.memberBlock.members.first {
            $0.decl.as(TypealiasDeclSyntax.self)?.identifier.text == "InjectedDependencies"
        }?.decl.as(TypealiasDeclSyntax.self)
        let injectedDependenciesInjectables: [String]
        func getTypeIdentifier(from memberTypeIdentifierSyntax: MemberTypeIdentifierSyntax) throws -> String {
            guard memberTypeIdentifierSyntax.name.text == "Dependencies" else {
                throw CustomError.message("typealias InjectedDependencies should have a form of ChildType1.Dependencies & ChildType2.Dependencies...")
            }
            var result = ""
            func prepend(_ name: String) {
                if result.isEmpty {
                    result = name
                    return
                }
                result = "\(name).\(result)"
            }
            var iterator = memberTypeIdentifierSyntax.baseType
            repeat {
                if let syntax = iterator.as(MemberTypeIdentifierSyntax.self) {
                    prepend(syntax.name.text)
                    iterator = syntax.baseType
                } else if let syntax = iterator.as(SimpleTypeIdentifierSyntax.self) {
                    prepend(syntax.name.text)
                    break
                } else {
                    throw CustomError.message("unexpected \(iterator)")
                }
            } while true
            return result
        }
        if let injectedDependencies = injectedDependenciesTypealias?.initializer.value.as(CompositionTypeSyntax.self) {
            injectedDependenciesInjectables = try injectedDependencies.elements.map {
                guard let memberTypeIdentifierSyntax = $0.type.as(MemberTypeIdentifierSyntax.self) else {
                    throw CustomError.message("typealias InjectedDependencies should have a form of ChildType1.Dependencies & ChildType2.Dependencies...")
                }
                return try getTypeIdentifier(from: memberTypeIdentifierSyntax)
            }
        } else if let injectedDependencies = injectedDependenciesTypealias?.initializer.value.as(MemberTypeIdentifierSyntax.self) {
            injectedDependenciesInjectables = try [getTypeIdentifier(from: injectedDependencies)]
        } else if injectedDependenciesTypealias == nil {
            injectedDependenciesInjectables = []
        } else {
            throw CustomError.message("typealias InjectedDependencies should have a form of ChildType1.Dependencies & ChildType2.Dependencies...")
        }

        let compositions = injectedDependenciesInjectables.isEmpty ? "" : "& " + injectedDependenciesInjectables.map {
            $0 + ".Dependencies"
        }.joined(separator: " & ")
        let dynamicCompositions = injectedDependenciesInjectables.isEmpty ? "" : "& " + injectedDependenciesInjectables.map {
            $0 + ".DependencyProvider"
        }.joined(separator: " & ")
        let keyPathsGetters = injectedDependenciesInjectables.map {
            "result.formUnion(\($0).getAllDependencyProviderKeyPaths())"
        }.joined(separator: "\n")

        let vars = injectedVars(of: declaration).map {
            let binding = $0.bindings.first
            return (name: binding?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text ?? "<nil1>",
                    type: binding?.typeAnnotation?.type.as(SimpleTypeIdentifierSyntax.self)?.name.text ?? "\(binding?.typeAnnotation?.type ?? "<nil2>")")
        }

        if injectedDependenciesInjectables.isEmpty && vars.isEmpty {
            throw CustomError.noInjectedMembers(location: context.location(of: declaration, at: .afterLeadingTrivia, filePathMode: .filePath))
        }

        let dependencyInitArguments = vars.map {
            "\($0.name): \($0.type)"
        }.joined(separator: ", ")
        let dynamicDependencyProviderInitArguments = dependencyInitArguments
        + (dynamicCompositions.isEmpty ? "" : "\(dependencyInitArguments.isEmpty ? "" : ",") nested nestedProvider: any ") + dynamicCompositions.dropping(prefix: "& ")
        var storageInitLiteral = vars.isEmpty ? "[:]" : ("[\n" + vars.map {
            "\\\(identifier).\($0.name): \($0.name)"
        }.joined(separator: ",\n") + "\n]")
        if !dynamicCompositions.isEmpty {
            storageInitLiteral = "nestedProvider._storage.merging(\(storageInitLiteral)) { $1 }"
        }

        var result: [DeclSyntax] = [
            "typealias Dependencies = \(raw: identifier)_OwnedInjectedVars & \(raw: identifier)_DependencyProviderProtocol \(raw: compositions)",
            "typealias DependencyProvider = \(raw: identifier)_DependencyProviderProtocol \(raw: dynamicCompositions)"
        ]

        result.append(contentsOf: [
            """

            @Sendable
            nonisolated static func getAllDependencyProviderKeyPaths() -> Set<AnyKeyPath> {
              var result = Set<AnyKeyPath>()
              result.formUnion(\(raw: identifier)_InjectedVars_allKeyPaths())
              \(raw: keyPathsGetters)
              return result
            }
            """,
            """

            // typealias DependencyStorage = DependencyStorageStruct<\(raw: identifier)>
            @dynamicMemberLookup
            struct DependencyStorage: DependencyProvider, DependencyStorageProtocol {
              typealias Owner = \(raw: identifier)

              var _storage: [AnyKeyPath: Any] // swiftlint:disable:this identifier_name

              init(_ storage: [AnyKeyPath: Any]) {
                self._storage = storage
              }

              init(_ dependencyProvider: any Dependencies) {
                self._storage = \(raw: identifier).getAllDependencyProviderKeyPaths().reduce(into: [:]) {
                  $0[$1] = dependencyProvider[keyPath: $1]
                }
              }

              init(_ dependencyProvider: any DependencyProvider) {
                // the dependencyProvider may be either dictionary-backed storage or a conforming struct
                // if it is a struct, collect all the needed values for all dependency keyPaths providing the keyPaths through the Task Local Storage
                self._storage = DependencyInjectionHelper.$collectKeyPaths.withValue(Owner.getAllDependencyProviderKeyPaths) {
                    dependencyProvider._storage
                }
              }

              subscript<T>(dynamicMember keyPath: KeyPath<\(raw: identifier)_InjectedVars, T>) -> T {
                self._storage[keyPath] as! T // swiftlint:disable:this force_cast
              }

              func mutating(_ transform: (MutableDependencyStorage<\(raw: identifier)_InjectedVars>) throws -> Void) rethrows -> Self {
                  var storage = _storage
                  try withUnsafeMutablePointer(to: &storage) { ptr in
                    let mutableDependencies = MutableDependencyStorage<\(raw: identifier)_InjectedVars>(ptr)
                    try transform(mutableDependencies)
                  }
                  return Self(storage)
              }
            }
            """,
            """

            nonisolated static func makeDependencies(\(raw: dynamicDependencyProviderInitArguments)) -> DependencyStorage {
                DependencyStorage(\(raw: storageInitLiteral))
            }

            """
        ])

        return result
    }

}

extension InjectableMacro: PeerMacro {

    public static func expansion<Context, Declaration>(of node: AttributeSyntax, providingPeersOf declaration: Declaration, in context: Context) throws -> [DeclSyntax] where Context: MacroExpansionContext, Declaration: DeclSyntaxProtocol {

        guard let declaration = declaration.asInjectableDeclSyntax() else {
            throw CustomError.message("@Injectable only applicable for classes, structs and actors")
        }
        let identifier = declaration.identifier.text
        let vars = injectedVars(of: declaration)
            .mutating {
                $0.attributes = nil
            }

        let keyPaths = vars.map {
            "\\" + identifier + "_InjectedVars." + ($0.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text)
        }

        var result = [DeclSyntax]()

        try result.append(contentsOf: [
            ProtocolDeclSyntax(
                "protocol \(raw: identifier)_InjectedVars"
            ) {
                for vardecl in vars {
                    vardecl.with(\.trailingTrivia, " { get }\n")
                }
            }.as(DeclSyntax.self)!,

            ProtocolDeclSyntax(
                "protocol \(raw: identifier)_OwnedInjectedVars: \(raw: identifier)_InjectedVars, DependenciesProtocol"
            ) {
                AssociatedtypeDeclSyntax.init(identifier: " Owner = \(raw: identifier)")
            }.as(DeclSyntax.self)!,

            """
            func \(raw: identifier)_InjectedVars_allKeyPaths() -> Set<AnyKeyPath> {
                [
                    \(raw: keyPaths.joined(separator: ",\n"))
                ]
            }
            """,

            ProtocolDeclSyntax(
                "protocol \(raw: identifier)_DependencyProviderProtocol: DependencyStorageProtocol"
            ) {
            }.as(DeclSyntax.self)!
        ])

        return result
    }

}

extension String {
    func dropping(prefix: String) -> String {
        return hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
    func dropping(suffix: String) -> String {
        return hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}

extension Sequence {

    func mutating(_ transform: (inout Element) throws -> Void) rethrows -> [Element] {
        try map {
            var mutable = $0
            try transform(&mutable)
            return mutable
        }
    }

}

extension TokenSyntax {

    var isWildcard: Bool {
        self.trimmed.description == "_"
    }

}
