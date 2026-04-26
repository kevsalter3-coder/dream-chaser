import Foundation
import SwiftData

@Model
class Household {
    var id: UUID
    var name: String
    var members: [String]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, members: [String] = []) {
        self.id = id
        self.name = name
        self.members = members
        self.createdAt = Date()
    }

    var primaryMember: String? { members.first }
}
