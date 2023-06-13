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
import SwiftCompilerPlugin
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
            $0 + ".DynamicDependencyProvider"
        }.joined(separator: " & ")
        let keyPathsGetters = injectedDependenciesInjectables.map {
            "result.formUnion(\($0).getAllDependencyProviderKeyPaths(from: dependencyProvider))"
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
        + (dynamicCompositions.isEmpty ? "" : "\(dependencyInitArguments.isEmpty ? "" : ",") nested nestedProvider: ") + dynamicCompositions.dropping(prefix: "& ")
        var storageInitLiteral = vars.isEmpty ? "[:]" : ("[\n" + vars.map {
            "\\\(identifier)_DependencyProvider.\($0.name): \($0.name)"
        }.joined(separator: ",\n") + "\n]")
        if !dynamicCompositions.isEmpty {
            storageInitLiteral = "nestedProvider._storage.merging(\(storageInitLiteral)) { $1 }"
        }

        var result: [DeclSyntax] = [
            "typealias Dependencies = \(raw: identifier)_DependencyProvider \(raw: compositions)",
            "typealias DynamicDependencyProvider = \(raw: identifier)_DynamicDependencyProvider \(raw: dynamicCompositions)"
        ]

#if swift(<5.9)
        result.append("typealias Injected = \(declaration.isStruct ? "OwnedInjectedStruct<\(raw: identifier)>.StructInjectedValue" : "ClassInjectedValue")")
#endif
        result.append(contentsOf: [
            """

            nonisolated static func getAllDependencyProviderKeyPaths(from dependencyProvider: Dependencies) -> Set<AnyKeyPath> {
              var result = Set<AnyKeyPath>()
              result.formUnion(\(raw: identifier)_DependencyProvider_allKeyPaths())
              \(raw: keyPathsGetters)
              return result
            }
            """,
            """

            @dynamicMemberLookup
            struct DynamicDependencies: DynamicDependencyProvider, DynamicDependenciesProtocol {
              var _storage: [AnyKeyPath: Any] // swiftlint:disable:this identifier_name

              init(_ storage: [AnyKeyPath: Any]) {
                self._storage = storage
              }

              init(_ dependencyProvider: Dependencies) {
                self._storage = \(raw: identifier).getAllDependencyProviderKeyPaths(from: dependencyProvider).reduce(into: [:]) {
                  $0[$1] = dependencyProvider[keyPath: $1]
                }
              }

              subscript<T>(dynamicMember keyPath: KeyPath<\(raw: identifier).Dependencies, T>) -> T {
                self._storage[keyPath] as! T // swiftlint:disable:this force_cast
              }
            }
            """,
            """

            nonisolated static func makeDependencies(\(raw: dynamicDependencyProviderInitArguments)) -> DynamicDependencies {
                DynamicDependencies(\(raw: storageInitLiteral))
            }

            @TaskLocal static var _currentDependencies: DynamicDependencies!

            """
        ])

#if swift(>=5.9)
        result.append("let dependencyProvider: DynamicDependencies = \(raw: identifier)._currentDependencies")
#endif

        result.append(contentsOf: try makers(for: declaration, in: context)
            .mutating { maker in
#if swift(<5.9)
                // hack to hide deprecation warning when using the `make` func but raise a warning when directly calling `init`
                // we can‘t make Injectable inits private in Xcode 14 since they can‘t be accessed from extensions
                // to be adjusted for Xcode 15 to require the inits to be private
                maker.attributes = maker.attributes?.appending(.attribute(deprecatedAttribute(for: identifier).with(\.trailingTrivia, .newline))) ?? [.attribute(deprecatedAttribute(for: identifier).with(\.trailingTrivia, .newline))]
                maker.identifier = "_\(maker.identifier)"
#endif
            }
            .map { $0.as(DeclSyntax.self)! })

        return result
    }

    static func makers(for declaration: some InjectableDeclSyntax, in context: some MacroExpansionContext) throws -> [FunctionDeclSyntax] {
        let identifier = declaration.identifier
        var result = [FunctionDeclSyntax]()

        let definedTypes: Set<String> = Set(declaration.memberBlock.members.compactMap {
            if let decl = $0.decl.asTypeDeclSyntax() {
                guard decl.identifier.text != "InjectedDependencies" else { return nil }
                return decl.identifier.text
            }
            return nil
        })

        for member in declaration.memberBlock.members {
            guard let initializer = member.decl.as(InitializerDeclSyntax.self) else { continue }

            //        TODO: let structError = Diagnostic(
            //                node: attribute, message: MyLibDiagnostic.notAStruct
            //            )
            //            context.diagnose(structError)
            //            return []
            //      guard initializer.modifiers?.contains(where: { $0.name.text == "private" }) == true else {
            // TODO: File/Line
            //        throw CustomError.message("Initializer for @Injectable should be declared `private`")

            //      }
            //        let modifier = initializer.modifiers!.first(where: { $0.name.text == "private" })!
            //        let modifier = initializer.modifiers!.first!.name //.as(DeclModifierSyntax.self)!
            let paramList = FunctionParameterListSyntax(initializer.signature.input.parameterList.mutating {
                let trimmedType = $0.type.trimmed.description
                if definedTypes.contains(trimmedType.components(separatedBy: ".")[0]) {
                    $0.type = "\(identifier).\(raw: trimmedType)"
                }
            })

            let initVars = paramList.map {
                ($0.firstName.isWildcard ? "" : $0.firstName.text + ": ") + ($0.secondName ?? $0.firstName).text
            }.joined(separator: ", ")

            let deprecationAttribute = initializer.attributes?.first(where: {
                guard let attribute = $0.as(AttributeSyntax.self) else { return false }
                return attribute.attributeName.description == "available"
                && attribute.argument?.as(AvailabilitySpecListSyntax.self)?.contains(where: { $0.entry.as(TokenSyntax.self)?.text == "deprecated" }) == true
            })
            guard deprecationAttribute != nil else {
                throw CustomError.noAttribute(deprecatedAttribute(for: identifier.text), location: context.location(of: initializer, at: .afterLeadingTrivia, filePathMode: .filePath))
            }

            let actorAttribute = initializer.attributes?.first(where: { $0.as(AttributeSyntax.self)?.attributeName.description == "MainActor" }) != nil ? "@MainActor\n" : nil

            var initCall = "self.init(\(initVars))"
            if declaration.isStruct {
                initCall = """

                // This is a little hack allowing us to dynamically provide storage keyPaths to @Injected property wrappers without passing extra init args
                // Properties in Swift structs (or classes) are initialized in the order they are defined in the code, from top to bottom
                // We use the TaskLocal mutable keyPath storage to initialize the @Injected properties one after another.
                var keyPaths = Array(\(identifier.text)_DependencyProvider_allKeyPaths())
                return withUnsafeMutablePointer(to: &keyPaths) { ptr in
                  StructInjectedKeyPathsStorage.$keyPaths.withValue(ptr) {
                    \(initCall)
                  }
                }

                """
            }

            let optionalMark = initializer.optionalMark != nil ? "?" : ""
            let throwsOrRethrows = initializer.signature.effectSpecifiers?.throwsSpecifier != nil ? "throws" : "rethrows"
            let tryKeyword = initializer.signature.effectSpecifiers?.throwsSpecifier != nil ? "try " : ""
            try result.append(contentsOf: [
                FunctionDeclSyntax("""
                \(raw: actorAttribute ?? "")static func make(with dependencies: \(identifier).Dependencies, \(paramList)\(paramList.isEmpty ? "" : ",") updateValues: ((MutableDynamicDependencies<\(identifier)_DependencyProvider>) throws -> Void)? = nil) \(raw: throwsOrRethrows) -> \(identifier)\(raw: optionalMark)
                """) {
                    """
                    var dependencies = DynamicDependencies(dependencies)
                    try updateValues?(MutableDynamicDependencies(&dependencies._storage))
                    return \(raw: tryKeyword)self.$_currentDependencies.withValue(dependencies) {
                      let instance = \(raw: tryKeyword)\(raw: initCall)
                      \(raw: declaration.isStruct ? "" : "// initialize dynamic dependency provider\n  _=instance.dependencyProvider")
                      return instance
                    }
                    """
                },
                FunctionDeclSyntax("""
                \(raw: actorAttribute ?? "")static func make(with dependencies: \(identifier).DynamicDependencyProvider, \(paramList)\(paramList.isEmpty ? "" : ",") updateValues: ((MutableDynamicDependencies<\(identifier)_DependencyProvider>) throws -> Void)? = nil) \(raw: throwsOrRethrows) -> \(identifier)\(raw: optionalMark)
                """) {
                    """
                    var dependencies = DynamicDependencies(dependencies._storage)
                    try updateValues?(MutableDynamicDependencies(&dependencies._storage))
                    return \(raw: tryKeyword)self.$_currentDependencies.withValue(dependencies) {
                      let instance = \(raw: tryKeyword)\(raw: initCall)
                      \(raw: declaration.isStruct ? "" : "// initialize dynamic dependency provider\n  _=instance.dependencyProvider")
                      return instance
                    }
                    """
                }
            ])
        }
        if result.isEmpty {
            throw CustomError.noInit(location: context.location(of: declaration, at: .afterLeadingTrivia, filePathMode: .filePath))
        }

        return result
    }

}

extension InjectableMacro: PeerMacro {

    // swiftlint:disable:next function_body_length
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
            "\\" + identifier + "_DependencyProvider." + ($0.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text)
        }

        var result = [DeclSyntax]()

        try result.append(contentsOf: [
            ProtocolDeclSyntax("protocol \(raw: identifier)_DependencyProvider") {
                for vardecl in vars {
                    vardecl.with(\.trailingTrivia, " { get }\n")
                }
            }.as(DeclSyntax.self)!,

            FunctionDeclSyntax("func \(raw: identifier)_DependencyProvider_allKeyPaths() -> Set<AnyKeyPath>") {"""
                [
                    \(raw: keyPaths.joined(separator: ",\n"))
                ]
            """}.as(DeclSyntax.self)!,

            """

            protocol \(raw: identifier)_DynamicDependencyProvider {
              var _storage: [AnyKeyPath: Any] { get set }
            }
            """
        ])

#if swift(<5.9)
        let makers = try makers(for: declaration, in: context)

        // hack to hide deprecation warning when using the `make` func but raise a warning when directly calling `init`:
        // first add Target_Factory protocol with deprecated `_make` functions declarations,
        try result.append(ProtocolDeclSyntax("private protocol \(raw: identifier)_Factory") {
            for functionSyntax in makers.mutating ({ functionSyntax in
                functionSyntax.identifier = "_\(functionSyntax.identifier)"
                functionSyntax.signature.input.parameterList = FunctionParameterListSyntax(functionSyntax.signature.input.parameterList.mutating { $0.defaultArgument = nil })
                functionSyntax.body = nil
            }) {
                functionSyntax
                    .with(\.leadingTrivia, .newline)
                    .with(\.trailingTrivia, .newline)
            }
        }.as(DeclSyntax.self)!)

        // then add an extension of the Target to conform to the protocol and introduce `make` functions calling the deprecated `_make` functions
        // this wont‘t raise a warning because we‘re calling ourselves using the protocol where the functions are not deprecated
        try result.append(ExtensionDeclSyntax("extension \(raw: identifier): \(raw: identifier)_Factory") {
            for functionSyntax in makers.mutating({
                $0.body = CodeBlockSyntax(statements: [
                    """

                    try (self as \(raw: identifier)_Factory.Type)._make(\(raw: $0.signature.input.parameterList.map { ($0.firstName.isWildcard ? "" : $0.firstName.text + ": ") + ($0.secondName ?? $0.firstName).text }.joined(separator: ",")))


                    """
                ])
            }) {
                functionSyntax.with(\.leadingTrivia, .newline).with(\.trailingTrivia, .newline)
            }
        }.as(DeclSyntax.self)!)
#endif

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
