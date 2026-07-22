import Foundation
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin

private struct PropertyInfo {
    let name: String
    let type: TypeSyntax?
    let hasDefault: Bool
    let isLet: Bool

    var trimmedType: String? {
        type?.trimmedDescription
    }
}

public struct SwiftClonableMacro: MemberMacro, ExtensionMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.classOnly
        }
        let className = classDecl.name.text
        let properties = storedProperties(of: classDecl)

        let assignments = properties
            .filter { !($0.isLet && $0.hasDefault) }
            .map { prop in
                let value = deepCopyExpression(
                    base: "other",
                    propertyName: prop.name,
                    type: prop.type
                )
                return "self.\(prop.name) = \(value)"
            }
            .joined(separator: "\n    ")

        let flagDecl: DeclSyntax = "private(set) var isCopy: Bool = false"

        let initDecl: DeclSyntax = """
            init(copying other: \(raw: className)) {
                \(raw: assignments)
                self.isCopy = true
            }
            """

        return [flagDecl, initDecl]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.classOnly
        }
        let className = classDecl.name.text

        let extensionDecl: DeclSyntax = """
            extension \(type.trimmed): Clonable {
                func copy() -> \(raw: className) {
                    return \(raw: className)(copying: self)
                }
            }
            """

        guard let ext = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [ext]
    }

    private static func storedProperties(of classDecl: ClassDeclSyntax) -> [PropertyInfo] {
        let storedVarDecls = classDecl.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter { decl in
                let isStatic = decl.modifiers.contains {
                    $0.name.tokenKind == .keyword(.static)
                }
                let isComputed = decl.bindings.contains {
                    $0.accessorBlock != nil
                }
                return !isStatic && !isComputed
            }

        return storedVarDecls.flatMap { decl in
            let isLet = decl.bindingSpecifier.tokenKind == .keyword(.let)

            return decl.bindings.compactMap { binding -> PropertyInfo? in
                guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                    return nil
                }

                let type = binding.typeAnnotation?.type
                let typeStr = type?.trimmedDescription ?? ""
                let isOptional = typeStr.hasSuffix("?") || typeStr.hasPrefix("Optional<")
                let hasDefault = binding.initializer != nil || (isOptional && !isLet)

                return PropertyInfo(
                    name: name,
                    type: binding.typeAnnotation?.type,
                    hasDefault: hasDefault,
                    isLet: isLet
                )
            }
        }
    }

    private static func deepCopyExpression(
        base: String,
        propertyName name: String,
        type: TypeSyntax?
    ) -> String {
        let ref = "\(base).\(name)"
        if isClosureType(type) {
            return ref
        }
        return "clonableDeepCopy(\(ref))"
    }

    private static func isClosureType(_ type: TypeSyntax?) -> Bool {
        guard let type else { return false }

        if type.is(FunctionTypeSyntax.self) {
            return true
        }

        if let optionalType = type.as(OptionalTypeSyntax.self) {
            return isClosureType(optionalType.wrappedType)
        }

        if let implicitlyUnwrapped = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return isClosureType(implicitlyUnwrapped.wrappedType)
        }

        if let attributedType = type.as(AttributedTypeSyntax.self) {
            return isClosureType(attributedType.baseType)
        }

        return false
    }

}

enum MacroError: Error, CustomStringConvertible {
    case classOnly

    var description: String {
        switch self {
        case .classOnly:
            return "@Clonable can only be applied to classes"
        }
    }
}

@main
struct ClonablePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SwiftClonableMacro.self,
    ]
}
