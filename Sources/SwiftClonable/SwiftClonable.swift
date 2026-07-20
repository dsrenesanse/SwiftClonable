public protocol Clonable: AnyObject, Sendable {
    func copy() -> Self
}

public func clonableDeepCopy<T>(_ value: T) -> T {
    return (value as? Clonable)?.copy() as? T ?? value
}

public func clonableDeepCopy<T>(_ value: T?) -> T? {
    guard let value = value else { return nil }
    return clonableDeepCopy(value)
}

public func clonableDeepCopy<T>(_ value: [T]) -> [T] {
    return value.map { clonableDeepCopy($0) }
}
public func clonableDeepCopy<K, V>(_ value: [K: V]) -> [K: V] {
    return value.mapValues { clonableDeepCopy($0) }
}

public func clonableDeepCopy<T: Hashable>(_ value: Set<T>) -> Set<T> {
    return Set(value.map { clonableDeepCopy($0) })
}


@attached(extension, conformances: Clonable, names: named(copy))
public macro Clonable() = #externalMacro(module: "SwiftClonableMacros", type: "SwiftClonableMacro")
