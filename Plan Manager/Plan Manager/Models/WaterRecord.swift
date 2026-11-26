//
//  WaterRecord.swift
//  Plan Manager
//

import Foundation
import SwiftUI

struct WaterRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let type: String
    let amount: Int
    let time: Date
    let iconName: String
    let colorHex: String

    enum CodingKeys: String, CodingKey {
        case id, type, amount, time, iconName, colorHex
    }

    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - Drink Types

struct DrinkType: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let defaultAmount: Int

    static let all: [DrinkType] = [
        DrinkType(name: "白开水", icon: "drop.fill", color: Color(red: 0.26, green: 0.65, blue: 0.96), defaultAmount: 250),
        DrinkType(name: "茶", icon: "leaf.fill", color: Color(red: 0.40, green: 0.73, blue: 0.42), defaultAmount: 200),
        DrinkType(name: "咖啡", icon: "cup.and.saucer.fill", color: Color(red: 0.43, green: 0.30, blue: 0.25), defaultAmount: 150),
        DrinkType(name: "牛奶", icon: "drop.halffull", color: Color(red: 1.0, green: 0.65, blue: 0.15), defaultAmount: 250),
        DrinkType(name: "奶茶", icon: "bubbles.and.sparkles.fill", color: Color(red: 0.74, green: 0.67, blue: 0.64), defaultAmount: 500),
        DrinkType(name: "果汁", icon: "wineglass.fill", color: Color(red: 1.0, green: 0.72, blue: 0.30), defaultAmount: 300),
        DrinkType(name: "饮料", icon: "takeoutbag.and.cup.and.straw.fill", color: Color(red: 0.94, green: 0.33, blue: 0.31), defaultAmount: 330),
        DrinkType(name: "其他", icon: "plus.circle", color: Color(red: 0.56, green: 0.64, blue: 0.68), defaultAmount: 200),
    ]
}
