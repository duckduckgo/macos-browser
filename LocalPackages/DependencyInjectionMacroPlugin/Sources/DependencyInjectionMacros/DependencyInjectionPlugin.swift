//
//  DependencyInjectionPlugin.swift
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

import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

#if swift(>=5.9)

// Xcode 15: uncomment this
// import CompilerPluginSupport
//
// @main
// struct DependencyInjectionPlugin: CompilerPlugin {
//     let providingMacros: [Macro.Type] = [
//         InjectableMacro.self,
//         InjectedMacro.self
//     ]
// }

@main
struct DependencyInjectionPlugin {
    static func main() {
    }
}

#else

final class InjectableVisitor: SyntaxVisitor {

    var sourceFile: SourceFileSyntax
    var path: String

    var imports: [ImportDeclSyntax] = []
    var output: [(identifier: String, extensionMembers: [DeclSyntax], peers: [DeclSyntax])] = []
    var errors: [(error: Error, node: any DeclGroupSyntax)] = []

    init(sourceFile: SourceFileSyntax, path: String) {
        self.sourceFile = sourceFile
        self.path = path

        super.init(viewMode: .fixedUp)
    }

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        imports.append(node)
        return .skipChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if conformsToInjectable(node) {
            process(node)
        }
        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if conformsToInjectable(node) {
            process(node)
        }
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        if conformsToInjectable(node) {
            process(node)
        }
        return .visitChildren
    }

    func conformsToInjectable(_ node: some DeclGroupSyntax) -> Bool {
        if let declaration = node.as(StructDeclSyntax.self) {
            return declaration.inheritanceClause?.inheritedTypeCollection.contains(where: { $0.typeName.as(SimpleTypeIdentifierSyntax.self)?.name.text == .Injectable }) == true
        } else if let declaration = node.as(ClassDeclSyntax.self) {
            return declaration.inheritanceClause?.inheritedTypeCollection.contains(where: { $0.typeName.as(SimpleTypeIdentifierSyntax.self)?.name.text == .Injectable }) == true
        } else if let declaration = node.as(ActorDeclSyntax.self) {
            return declaration.inheritanceClause?.inheritedTypeCollection.contains(where: { $0.typeName.as(SimpleTypeIdentifierSyntax.self)?.name.text == .Injectable }) == true
        } else {
            return false
        }
    }

    func process(_ node: some DeclGroupSyntax) {
        guard let declaration = node as? DeclSyntaxProtocol,
              let identifier = node.asInjectableDeclSyntax()?.identifier else { return }

        let attribute = AttributeSyntax(stringLiteral: "@Injectable")
        let context = BasicMacroExpansionContext(sourceFiles: [self.sourceFile: .init(moduleName: "DuckDuckGo", fullFilePath: self.path)])

        do {
            let extensionMembers = try InjectableMacro.expansion(of: attribute, providingMembersOf: node, in: context)
            let peers = try InjectableMacro.expansion(of: attribute, providingPeersOf: declaration, in: context)

            output.append( (identifier.text, extensionMembers: extensionMembers, peers: peers) )
        } catch {
            self.errors.append( (error, node) )
        }
    }
}

@main
struct DependencyInjectionPlugin {

    static func main() {
        do {
            try worker()
        } catch {
            print(error)
            exit(-1)
        }
    }

    // swiftlint:disable:next function_body_length
    static func worker() throws {
        let fm = FileManager.default
        let formatter = ISO8601DateFormatter()

        for file in ProcessInfo().arguments[1...] {
            try autoreleasepool {
                let modified = try fm.attributesOfItem(atPath: file)[.modificationDate] as? Date ?? { throw CocoaError(.fileReadUnknown) }()
                let contents = try NSString(contentsOfFile: file, encoding: NSUTF8StringEncoding)

                let syntax = Parser.parse(source: contents as String)
                let visitor = InjectableVisitor(sourceFile: syntax, path: file)
                visitor.walk(syntax)

                if let error = visitor.errors.first?.error {
                    throw error
                }

                let fileName = file.deletingPathExtension.lastPathComponent.appendingPathExtension(.generatedSwift)
                let outputPath = fm.currentDirectoryPath.appendingPathComponent(fileName)

                var output = "// \(formatter.string(from: modified))"

                if !visitor.output.isEmpty {
                    output.append(visitor.imports.map {
                        let name = $0.path.description.trimmingCharacters(in: .whitespaces)
                        if Set(["Foundation", "Combine", "AppKit", "Cocoa", "DependencyInjection", "Common", "WebKit"]).contains(name) {
                            return $0.description
                        }
                        return """

                        #if canImport(\(name))
                        \($0.description.trimmingCharacters(in: .whitespacesAndNewlines))
                        #endif

                        """
                    }.joined())

                    if !visitor.imports.contains(where: { $0.path.description.trimmingCharacters(in: .whitespaces) == .DependencyInjection }) {
                        output.append("import " + .DependencyInjection)
                    }

                    for result in visitor.output {
                        output += """

                        extension \(result.identifier) {
                            \(result.extensionMembers.map { $0.description }.joined(separator: "\n"))
                        }

                        \(result.peers.map { $0.description }.joined(separator: "\n"))

                        """
                    }
                }

                let data = output.data(using: .utf8)!
                if data.count == (try? fm.attributesOfItem(atPath: outputPath)[.size]) as? Int,
                   let oldData = try? Data(contentsOf: URL(fileURLWithPath: outputPath)),
                   oldData == data {

                    return
                }
                try output.write(toFile: outputPath, atomically: false, encoding: .utf8)
            }

        }
    }

}

extension String {

    static let DependencyInjection = "DependencyInjection"
    static let Injectable = "Injectable"
    static let generatedSwift = "generated.swift"

    var deletingPathExtension: String {
        (self as NSString).deletingPathExtension
    }

    var lastPathComponent: String {
        (self as NSString).lastPathComponent
    }

    func appendingPathExtension(_ ext: String) -> String {
        (self as NSString).appendingPathExtension(ext) ?? self
    }

    func appendingPathComponent(_ component: String) -> String {
        (self as NSString).appendingPathComponent(component)
    }

}

#endif
