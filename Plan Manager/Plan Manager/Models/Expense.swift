//
//  Expense.swift
//  Plan Manager
//

import Foundation
import SwiftUI

struct Expense: Codable, Identifiable, Equatable {
    let id: Int?
    let userId: Int?
    var amount: Double
    var category: String
    var note: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case amount
        case category
        case note
        case createdAt = "created_at"
    }

    init(id: Int? = nil, userId: Int? = nil, amount: Double, category: String, note: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.amount = amount
        self.category = category
        self.note = note
        self.createdAt = createdAt
    }
}

// MARK: - Category Helper

enum ExpenseCategory: String, CaseIterable {
    case food = "餐饮"
    case transport = "交通"
    case shopping = "购物"
    case entertainment = "娱乐"
    case other = "其他"

    var icon: String {
        switch self {
        case .food: return "cart.fill"
        case .transport: return "car.fill"
        case .shopping: return "bag.fill"
        case .entertainment: return "gamecontroller.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .food: return [Color(hex: "F0E68C"), Color(hex: "EEE8AA")] // Khaki -> Pale Goldenrod
        case .transport: return [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.15, green: 0.39, blue: 0.92)]
        case .shopping: return [Color(red: 0.93, green: 0.29, blue: 0.60), Color(red: 0.86, green: 0.15, blue: 0.47)]
        case .entertainment: return [Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.49, green: 0.23, blue: 0.93)]
        case .other: return [Color(red: 0.39, green: 0.45, blue: 0.55), Color(red: 0.28, green: 0.34, blue: 0.41)]
        }
    }

    static func from(_ name: String) -> ExpenseCategory {
        return ExpenseCategory.allCases.first { $0.rawValue == name } ?? .other
    }
}
