import SwiftClonable

@Clonable
final class Person: @unchecked Sendable {
    let name: String
    var age: Int = 0

    init(name: String) {
        self.name = name
    }
}

let original = Person(name: "Ada")
original.age = 36

let clone = original.copy()
print("original.isCopy = \(original.isCopy)")
print("clone.isCopy = \(clone.isCopy)")
print("clone: \(clone.name), \(clone.age)")
