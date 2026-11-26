//
//  Plan.swift
//  Plan Manager
//

import Foundation

struct Plan: Codable, Identifiable, Equatable {
    let id: Int
    let userId: Int
    var content: String
    var isPinned: Bool
    var tag: String
    var status: String
    var executionDate: Date
    let createdAt: Date
    let updatedAt: Date?

    var isCompleted: Bool {
        status == "completed"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case content
        case isPinned = "is_pinned"
        case tag
        case status
        case executionDate = "execution_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: Int,
        userId: Int,
        content: String,
        isPinned: Bool = false,
        tag: String = "",
        status: String,
        executionDate: Date,
        createdAt: Date,
        updatedAt: Date?
    ) {
        self.id = id
        self.userId = userId
        self.content = content
        self.isPinned = isPinned
        self.tag = tag
        self.status = status
        self.executionDate = executionDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        userId = try container.decodeIfPresent(Int.self, forKey: .userId) ?? 0
        content = try container.decode(String.self, forKey: .content)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? ""
        status = try container.decode(String.self, forKey: .status)
        executionDate = try container.decode(Date.self, forKey: .executionDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}
