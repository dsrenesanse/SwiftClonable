import SwiftClonable

@Clonable
final class Address: @unchecked Sendable {
    let street: String
    var city: String = ""

    init(street: String) {
        self.street = street
    }
}

@Clonable
final class Pet: @unchecked Sendable {
    let name: String

    init(name: String) {
        self.name = name
    }
}

@Clonable
final class Person: @unchecked Sendable {
    let name: String
    let birthYear: Int
    var age: Int = 0
    var address: Address
    var pets: [Pet] = []
    var scores: [String: Int] = [:]
    var friends: [String: Pet] = [:]
    var nickname: String?
    var tags: Set<String> = []
    var onUpdate: (@Sendable (Int) -> Void)?

    init(name: String, birthYear: Int, address: Address) {
        self.name = name
        self.birthYear = birthYear
        self.address = address
    }
}

func check(_ label: String, _ condition: Bool) {
    print("\(condition ? "✅" : "❌") \(label)")
}

let address = Address(street: "Main St 1")
address.city = "Springfield"

let original = Person(name: "Ada", birthYear: 1990, address: address)
original.age = 36
original.pets = [Pet(name: "Rex"), Pet(name: "Milo")]
original.scores = ["math": 100, "history": 80]
original.friends = ["best": Pet(name: "Buddy")]
original.nickname = "Ad"
original.tags = ["engineer", "chess"]
original.onUpdate = { newAge in print("age updated to \(newAge)") }

let clone = original.copy()

// isCopy flag
check("original.isCopy is false", original.isCopy == false)
check("clone.isCopy is true", clone.isCopy == true)
check("nested address copy has isCopy true", clone.address.isCopy == true)
check("nested pet copies have isCopy true", clone.pets.allSatisfy { $0.isCopy })
check("copy of copy keeps isCopy true", clone.copy().isCopy == true)

// values are equal
check("name copied", clone.name == "Ada")
check("birthYear copied", clone.birthYear == 1990)
check("age copied", clone.age == 36)
check("address values copied", clone.address.street == "Main St 1" && clone.address.city == "Springfield")
check("pets copied", clone.pets.map(\.name) == ["Rex", "Milo"])
check("scores copied", clone.scores == ["math": 100, "history": 80])
check("friends copied", clone.friends["best"]?.name == "Buddy")
check("nickname copied", clone.nickname == "Ad")
check("tags copied", clone.tags == ["engineer", "chess"])
check("closure carried over", clone.onUpdate != nil)

// copies are deep: reference types are new instances
check("clone is a different instance", clone !== original)
check("address is a different instance", clone.address !== original.address)
check("pets are different instances", clone.pets[0] !== original.pets[0] && clone.pets[1] !== original.pets[1])
check("dictionary values are different instances", clone.friends["best"] !== original.friends["best"])

// mutating the original does not affect the clone
original.address.city = "Shelbyville"
original.pets.append(Pet(name: "Intruder"))
original.scores["math"] = 0
check("clone address unaffected by original mutation", clone.address.city == "Springfield")
check("clone pets unaffected by original mutation", clone.pets.count == 2)
check("clone scores unaffected by original mutation", clone.scores["math"] == 100)

// Clonable protocol exposes isCopy
let asClonable: any Clonable = clone
check("isCopy accessible via Clonable protocol", asClonable.isCopy == true)
