import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum CustomError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let text):
            return text
        }
    }
}

extension SyntaxProtocol {

    var identifier: String? {
        if let declaration = self.as(StructDeclSyntax.self) {
            return declaration.identifier.text
        } else if let declaration = self.as(ClassDeclSyntax.self) {
            return declaration.identifier.text
        } else if let declaration = self.as(ActorDeclSyntax.self) {
            return declaration.identifier.text
        } else {
            return nil
        }
    }

}

protocol WithMemberBlock {
    var memberBlock: MemberDeclBlockSyntax { get }
}

extension StructDeclSyntax: WithMemberBlock {}
extension ClassDeclSyntax: WithMemberBlock {}
extension ActorDeclSyntax: WithMemberBlock {}

public struct InjectableMacro: MemberMacro {

    // Add members to Injectable
    // swiftlint:disable:next function_body_length
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        guard let identifier = declaration.identifier else {
            throw CustomError.message("@Injectable only applicable for classes, structs and actors")
        }

        //      if declaration.identifier.text == "Tab" {

        //    }
        //    guard let i = declaration.as(InitializerDeclSyntax.self) else { return [] }

        //    let memberList = MemberDeclListSyntax(
        //      declaration.memberBlock.members
        //      //        .filter {
        //      //        $0.decl.isObservableStoredProperty
        //      //      }
        //    )
        //    let members = declaration.memberBlock.members.map { "\($0.decl.kind): " + $0.decl.description }

        let injectedDependenciesInjectables = try declaration.attributes?.lazy
            .compactMap {
                $0.as(AttributeSyntax.self)
            }
            .first(where: {
                $0.attributeName.description == "InjectedDependencies"
            })
            .map { attribute -> [String] in
                guard case let .argumentList(arguments) = attribute.argument else {
                    throw CustomError.message("InjectedDependencies invalid declaration")
                }
                return arguments.compactMap {
                    $0.expression.as(MemberAccessExprSyntax.self)?.base?.as(IdentifierExprSyntax.self)?.identifier.text
                }
            } ?? []
        let compositions = injectedDependenciesInjectables.isEmpty ? "" : "& " + injectedDependenciesInjectables.map {
            $0 + ".DependencyProvider"
        }.joined(separator: " & ")
        let dynamicCompositions = injectedDependenciesInjectables.isEmpty ? "" : "& " + injectedDependenciesInjectables.map {
            $0 + ".DynamicDependencyProvider"
        }.joined(separator: " & ")
        let keyPathsGetters = injectedDependenciesInjectables.map {
            "result.formUnion(\($0).getAllDependencyProviderKeyPaths(from: dependencyProvider))"
        }.joined(separator: "\n")


        var paramList: FunctionParameterListSyntax!
        var actorAttribute: String?
        for member in declaration.memberBlock.members {
            guard let initializer = member.decl.as(InitializerDeclSyntax.self) else { continue }
            //      guard initializer.modifiers?.contains(where: { $0.name.text == "private" }) == true else {
            // TODO: File/Line
            //        throw CustomError.message("Initializer for @Injectable should be declared `private`")

            //      }
            //        let modifier = initializer.modifiers!.first(where: { $0.name.text == "private" })!
            //        let modifier = initializer.modifiers!.first!.name //.as(DeclModifierSyntax.self)!
            paramList = initializer.signature.input.parameterList
            actorAttribute = initializer.attributes?.first(where: { $0.as(AttributeSyntax.self)?.attributeName.description == "MainActor" }) != nil ? "@MainActor\n" : nil
        }
        if paramList == nil {
            paramList = []
        }


        //    throw CustomError.message("\(i.description)")
        //    guard let property = member.as(VariableDeclSyntax.self),
        //          property.isStoredProperty
        //    else {
        //      return []
        //    }

        //    guard case let .argumentList(arguments) = node.argument,
        //          let firstElement = arguments.first,
        //          let stringLiteral = firstElement.expression
        //      .as(StringLiteralExprSyntax.self),
        //          stringLiteral.segments.count == 1,
        //          case let .stringSegment(wrapperName)? = stringLiteral.segments.first else {
        //      throw CustomError.message("macro requires a string literal containing the name of an attribute")
        //    }

        //    let storage: DeclSyntax = """
        //      @AddCompletionHandler
        //        func test(a: Int, for b: String, _ value: Double) async -> String {
        //        return b
        //      }
        //    """
        //    let storage: DeclSyntax = "var _storage: [String: Any] = [:]"

        //    return [
        //      storage.with(\.leadingTrivia, [.newlines(1), .spaces(2)])
        //    ]


        //    return [
        //      "init(a: Int, b: Int) { fatalError() }"

        //      AttributeSyntax(i)!
        //      AttributeSyntax(
        //        attributeName: SimpleTypeIdentifierSyntax(
        //          name: .identifier(wrapperName.content.text)
        //        )
        //      )
        //      .with(\.leadingTrivia, [.newlines(1), .spaces(2)])
        //    ]

        let members = declaration.memberBlock.members.compactMap {
            $0.decl.as(VariableDeclSyntax.self)
        }.filter {
            $0.attributes?.first?.trimmed.description == "@Injected"
        }
        let vars = members.map {
            let binding = $0.bindings.first
            return (name: binding?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text ?? "<nil1>",
                    type: binding?.typeAnnotation?.type.as(SimpleTypeIdentifierSyntax.self)?.name.text ?? "\(binding?.typeAnnotation?.type ?? "<nil2>")")
        }

        //    let vars = members.map {
        //      $0.description
        //        .trimmingCharacters(in: .whitespacesAndNewlines)
        //        .dropping(prefix: "@Injected")
        //        .trimmingCharacters(in: .whitespacesAndNewlines)
        ////        + " { fatalError() }"
        //    }
        let initVars = paramList?.map {
            let varName = $0.firstName.text
            return "\(varName): \(varName)"
        }.joined(separator: ", ") ?? ""

        let dependencyInitArguments = vars.map {
            "\($0.name): \($0.type)"
        }.joined(separator: ", ")
        let dynamicDependencyProviderInitArguments = dependencyInitArguments
        + (dynamicCompositions.isEmpty ? "" : "\(dependencyInitArguments.isEmpty ? "" : ",") nested nestedProvider: ") + dynamicCompositions.dropping(prefix: "& ")
        var storageInitLiteral = "[\n" + vars.map {
            "\\\(identifier)_DependencyProvider.\($0.name): \($0.name)"
        }.joined(separator: ",\n") + "\n]"
        if !dynamicCompositions.isEmpty {
            storageInitLiteral = "nestedProvider._storage.merging(\(storageInitLiteral)) { $1 }"
        }


        //    \(raw: vars.joined(separator: "\n"))




        //    return ["""
        //      typealias DependencyProvider = \(raw: declaration.identifier.text)_DependencyProvider
        //
        //      @dynamicMemberLookup
        //      struct Dependencies: DependencyProvider {
        //        var _storage = [AnyKeyPath: Any]()
        //
        //        init() {
        //          self.init(with: \(raw: declaration.identifier.text)._currentDependencies)
        //        }
        //
        //        init(with dependencyProvider: DependencyProvider) {
        //          (raw: initVarsFromProvider)
        //        }
        //
        //        subscript<T>(dynamicMember keyPath: KeyPath<Extension, T>) -> T {
        //            self.value[keyPath: keyPath]
        //        }
        //
        //      }
        //      let dependencyProvider = Dependencies()
        //
        //      @TaskLocal private static var _currentDependencies: DependencyProvider!
        //    """]

        return ["""
      typealias DependencyProvider = \(raw: identifier)_DependencyProvider \(raw: compositions)
      typealias DynamicDependencyProvider = \(raw: identifier)_DynamicDependencyProvider \(raw: dynamicCompositions)

      static func getAllDependencyProviderKeyPaths(from dependencyProvider: DependencyProvider) -> Set<AnyKeyPath> {
        var result = Set<AnyKeyPath>()
        result.formUnion(\(raw: identifier)_DependencyProvider_allKeyPaths())
        \(raw: keyPathsGetters)
        return result
      }

      @dynamicMemberLookup
      struct DynamicDependencies: DynamicDependencyProvider {
        var _storage: [AnyKeyPath: Any]

        init() {
          self._storage = \(raw: identifier)._currentDependencies._storage
        }
        init(_ storage: [AnyKeyPath: Any]) {
          self._storage = storage
        }
        init(_ dependencyProvider: DependencyProvider) {
          self._storage = \(raw: identifier).getAllDependencyProviderKeyPaths(from: dependencyProvider).reduce(into: [:]) {
            $0[$1] = dependencyProvider[keyPath: $1]
          }
        }
        init(_ dependencyProvider: DynamicDependencyProvider) {
          self._storage = dependencyProvider._storage
        }

        subscript<T>(dynamicMember keyPath: KeyPath<\(raw: identifier)_DependencyProvider, T>) -> T {
          self._storage[keyPath] as! T
        }
      }

      static func makeDependencies(\(raw: dynamicDependencyProviderInitArguments)) -> DynamicDependencies {
          DynamicDependencies(\(raw: storageInitLiteral))
      }

      //let dependencyProvider = DynamicDependencies()
        private nonisolated static let dependencyProviderKey = UnsafeRawPointer(bitPattern: "dependencyProvider".hashValue)!
        nonisolated var dependencyProvider: DynamicDependencies {
            get {
                if let dependencyProvider = objc_getAssociatedObject(self, Self.dependencyProviderKey) as? DynamicDependencies {
                    return dependencyProvider
                }
                let dependencyProvider = DynamicDependencies.init()
                objc_setAssociatedObject(self, Self.dependencyProviderKey, dependencyProvider, .OBJC_ASSOCIATION_RETAIN)

                return dependencyProvider
            }
            set {
                objc_setAssociatedObject(self, Self.dependencyProviderKey, newValue, .OBJC_ASSOCIATION_RETAIN)
            }
        }

      @TaskLocal private static var _currentDependencies: DynamicDependencies!

      \(raw: actorAttribute ?? "")static func make(with dependencies: DependencyProvider, \(paramList)\(paramList.isEmpty ? "" : ",") updateValues: ((MutableDynamicDependencies<\(raw: identifier)_DependencyProvider>) throws -> Void)? = nil) rethrows -> Self {
        var dependencies = DynamicDependencies(dependencies)
        try updateValues?(MutableDynamicDependencies(&dependencies._storage))
        return self.$_currentDependencies.withValue(dependencies) {
          return self.init(\(raw: initVars))
        }
      }

      \(raw: actorAttribute ?? "")static func make(with dependencies: DynamicDependencyProvider, \(paramList)\(paramList.isEmpty ? "" : ",") updateValues: ((MutableDynamicDependencies<\(raw: identifier)_DependencyProvider>) throws -> Void)? = nil) rethrows -> Self {
        var dependencies = DynamicDependencies(dependencies)
        try updateValues?(MutableDynamicDependencies(&dependencies._storage))
        return self.$_currentDependencies.withValue(dependencies) {
          return self.init(\(raw: initVars))
        }
      }
    """]
    }

}

extension InjectableMacro: PeerMacro {

    public static func expansion<Context, Declaration>(of node: AttributeSyntax, providingPeersOf declaration: Declaration, in context: Context) throws -> [DeclSyntax] where Context : MacroExpansionContext, Declaration : DeclSyntaxProtocol {

        guard let identifier = declaration.identifier,
              let memberBlock = (declaration as? WithMemberBlock)?.memberBlock else {
            throw CustomError.message("@Injectable only applicable for classes, structs and actors")
        }

        let vars = memberBlock.members.compactMap {
            $0.decl.as(VariableDeclSyntax.self)
        }.filter {
            $0.attributes?.first?.trimmed.description == "@Injected"
        }.map {
            $0.description
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .dropping(prefix: "@Injected")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        //    injectableProtocolVars[decl.identifier.text, default: []].formUnion(vars)

        let protocolVars = vars.map { $0 + " { get }" }
        let keyPaths = vars.map {
            "\\" + identifier + "_DependencyProvider." + ($0.split(separator: " ", maxSplits: 1).last?.components(separatedBy: ":").first ?? "<nil3>") // TODO: get identifier
        }
        //    throw CustomError.message("`\(d)`")

        //    let memberList = try MemberDeclListSyntax(
        //      decl.memberBlock.members.filter {
        //
        //        if let property = $0.as(VariableDeclSyntax.self),
        //           property.attributes?.isEmpty == false {
        //          throw CustomError.message("`\(property.attributes!.first!.description)`")
        //          return true
        //        } //.contains(where: { $0. })
        //        return false
        ////        $0.decl.isObservableStoredProperty
        //      }
        //    )
        //    throw CustomError.message("`\(memberList.first!.description)`")

        //    let descr = decl.identifier.text

        //    throw CustomError.message("`\(descr)`")

        return ["""
      protocol \(raw: identifier)_DependencyProvider {
        \(raw: protocolVars.joined(separator: "\n"))
      }
      func \(raw: identifier)_DependencyProvider_allKeyPaths() -> Set<AnyKeyPath> {
        [
          \(raw: keyPaths.joined(separator: ",\n"))
        ]
      }

      protocol \(raw: identifier)_DynamicDependencyProvider {
        var _storage: [AnyKeyPath: Any] { get set }
      }

    """]
        //    return [
        //      """
        //        protocol \(raw: decl.identifier.text)_DependencyProvider {
        //          \(raw: protocolVars.joined(separator: "\n"))
        //        }
        //      """
        //    ]
    }

}

extension String {
    func dropping(prefix: String) -> String {
        return hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
