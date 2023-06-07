import Foundation
import SwiftCompilerPlugin
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

#if swift(>=5.9)
@main
struct DependencyInjectionPlugin: CompilerPlugin {

    let providingMacros: [Macro.Type] = [
        //        StringifyMacro.self,
        InjectableMacro.self
    ]

}
#else

struct ListItem: Codable {

    let path: String
    let modified: Date

}

final class InjectableVisitor: SyntaxVisitor {

    var imports: [ImportDeclSyntax] = []
    var output: [(identifier: String, extensionMembers: [DeclSyntax], peers: [DeclSyntax])] = []
    var errors: [(error: Error, node: any DeclGroupSyntax)] = []

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
            return declaration.inheritanceClause?.inheritedTypeCollection.contains(where: { $0.typeName.as(SimpleTypeIdentifierSyntax.self)?.name.text == "Injectable" }) == true
        } else if let declaration = node.as(ClassDeclSyntax.self) {
            return declaration.inheritanceClause?.inheritedTypeCollection.contains(where: { $0.typeName.as(SimpleTypeIdentifierSyntax.self)?.name.text == "Injectable" }) == true
        } else if let declaration = node.as(ActorDeclSyntax.self) {
            return declaration.inheritanceClause?.inheritedTypeCollection.contains(where: { $0.typeName.as(SimpleTypeIdentifierSyntax.self)?.name.text == "Injectable" }) == true
        } else {
            return false
        }
    }

    func process(_ node: some DeclGroupSyntax) {
        guard let declaration = node as? DeclSyntaxProtocol,
              let identifier = node.identifier else { return }

        let attribute = AttributeSyntax(stringLiteral: "@Injectable")
        let context = BasicMacroExpansionContext()

        do {
            let extensionMembers = try InjectableMacro.expansion(of: attribute, providingMembersOf: node, in: context)
            let peers = try InjectableMacro.expansion(of: attribute, providingPeersOf: declaration, in: context)

            output.append( (identifier, extensionMembers: extensionMembers, peers: peers) )
        } catch {
            self.errors.append( (error, node) )
        }
    }
}

@main
struct DependencyInjectionPlugin {

    static func main() async throws {
        let fileListPath = ProcessInfo().arguments[1]
        let files = try JSONDecoder().decode([ListItem].self, from: Data(contentsOf: URL(fileURLWithPath: fileListPath)))

        for file in (try? FileManager.default.contentsOfDirectory(atPath: FileManager.default.currentDirectoryPath)) ?? [] {
            try? FileManager.default.removeItem(atPath: (FileManager.default.currentDirectoryPath as NSString).appendingPathComponent(file))
        }


        for file in files {
            try autoreleasepool {
                let contents = try NSString(contentsOfFile: file.path, encoding: NSUTF8StringEncoding)
                guard contents.range(of: "Injectable").location != NSNotFound else {
                    return
                }
                let syntax = Parser.parse(source: contents as String)
                let visitor = InjectableVisitor(viewMode: .fixedUp)
                visitor.walk(syntax)

                if let error = visitor.errors.first?.error {
                    throw error
                }
                if visitor.output.isEmpty { return }

                let fileName = ((file.path as NSString).deletingPathExtension as NSString).lastPathComponent + ".generated.swift"
                let outputPath = FileManager.default.currentDirectoryPath + "/" + fileName

                var output = """
                    \(visitor.imports.map { $0.description }.joined(separator: "\n"))
                    \(visitor.imports.contains(where: { $0.path.description.trimmingCharacters(in: .whitespaces) == "DependencyInjection" }) ? "" : "import DependencyInjection")
                """

                for result in visitor.output {
                    output += """

                    extension \(result.identifier) {
                        \(result.extensionMembers.map { $0.description }.joined(separator: "\n"))
                    }

                    \(result.peers.map { $0.description }.joined(separator: "\n"))

                    """
                }

                try output.write(toFile: outputPath, atomically: false, encoding: .utf8)
            }

        }
    }

}

#endif

extension String {
    func dropping(prefix: String) -> String {
        return hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
