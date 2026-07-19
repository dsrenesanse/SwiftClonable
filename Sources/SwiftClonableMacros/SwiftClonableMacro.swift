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

public struct SwiftClonableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        
        let classDecl = declaration as! ClassDeclSyntax
        let className = classDecl.name.text
        
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
        
        //test after...
        let properties: [PropertyInfo] = storedVarDecls.flatMap { decl in
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
        
        let initProps = properties.filter { !$0.hasDefault }
        let postInitProps = properties.filter { $0.hasDefault && !$0.isLet }
        let initArgs = initProps
            .map { prop in
                let value = deepCopyExpression(
                    propertyName: prop.name,
                    type: prop.type
                )
                return "\(prop.name): \(value)"
            }
            .joined(separator: ",\n            ")
        
        let initCall: String
        if initProps.isEmpty {
            initCall = "\(className)()"
        } else {
            initCall = """
            \(className)(
                        \(initArgs)
                    )
            """
        }
        
        let assignments = postInitProps
            .map { prop in
                let value = deepCopyExpression(
                    propertyName: prop.name,
                    type: prop.type
                )
                return "instance.\(prop.name) = \(value)"
            }
            .joined(separator: "\n        ")
        
        let bodyLines: String
        if postInitProps.isEmpty {
            bodyLines = "return \(initCall)"
        } else {
            bodyLines = """
            let instance = \(initCall)
                    \(assignments)
                    return instance
            """
        }
        
        let copyBody = """
        func copy() -> \(className) {
                    \(bodyLines)
                }
        """
        
        let extensionDecl: DeclSyntax = """
            extension \(type.trimmed): Clonable {
                \(raw: copyBody)
            }
            """
        
        guard let ext = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }
        
        return [ext]
    }
    
    private static func deepCopyExpression(
        propertyName name: String,
        type: TypeSyntax?
    ) -> String {
        let selfRef = "self.\(name)"
        if isClosureType(type) {
            return selfRef
        }
        return "clonableDeepCopy(\(selfRef))"
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
