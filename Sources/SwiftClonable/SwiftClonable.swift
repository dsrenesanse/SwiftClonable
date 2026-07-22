public protocol Clonable: AnyObject, Sendable {
    var isCopy: Bool { get }
    func copy() -> Self
}

public func clonableDeepCopy<T>(_ value: T) -> T {
    return (value as? Clonable)?.copy() as? T ?? value
}

public func clonableDeepCopy<T>(_ value: T?) -> T? {
    guard let value = value else { return nil }
    let copied: T = clonableDeepCopy(value)
    return copied
}

public func clonableDeepCopy<T>(_ value: [T]) -> [T] {
    guard T.self is Clonable.Type else { return value }
    return value.map { clonableDeepCopy($0) }
}
public func clonableDeepCopy<K, V>(_ value: [K: V]) -> [K: V] {
    guard V.self is Clonable.Type else { return value }
    return value.mapValues { clonableDeepCopy($0) }
}

public func clonableDeepCopy<T: Hashable>(_ value: Set<T>) -> Set<T> {
    guard T.self is Clonable.Type else { return value }
    return Set(value.map { clonableDeepCopy($0) })
}


@attached(member, names: named(isCopy), named(init(copying:)))
@attached(extension, conformances: Clonable, names: named(copy))
public macro Clonable() = #externalMacro(module: "SwiftClonableMacros", type: "SwiftClonableMacro")
