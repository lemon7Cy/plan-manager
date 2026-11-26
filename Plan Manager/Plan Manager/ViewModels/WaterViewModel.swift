//
//  WaterViewModel.swift
//  Plan Manager
//

import Foundation
import SwiftUI

@Observable
@MainActor
class WaterViewModel {
    var records: [WaterRecord] = []
    var dailyGoal: Int = 2000
    var reminderEnabled: Bool = false
    var reminderStartHour: Int = 8
    var reminderInterval: Int = 60

    private let storage = LocalStorage.shared

    var todayTotal: Int {
        records.reduce(0) { $0 + $1.amount }
    }

    var progress: Double {
        min(Double(todayTotal) / Double(dailyGoal), 1.0)
    }

    init() {
        loadData()
    }

    func loadData() {
        records = storage.loadWaterRecords(for: Date())
        dailyGoal = storage.dailyGoal
        reminderEnabled = storage.reminderEnabled
        reminderStartHour = storage.reminderStartHour
        reminderInterval = storage.reminderInterval
    }

    func addRecord(drinkType: DrinkType, amount: Int) {
        let record = WaterRecord(
            type: drinkType.name,
            amount: amount,
            time: Date(),
            iconName: drinkType.icon,
            colorHex: drinkType.color.hex
        )

        records.insert(record, at: 0)
        saveRecords()
    }

    func deleteRecord(at index: Int) {
        guard index < records.count else { return }
        records.remove(at: index)
        saveRecords()
    }

    func deleteRecord(_ record: WaterRecord) {
        records.removeAll { $0.id == record.id }
        saveRecords()
    }

    private func saveRecords() {
        storage.saveWaterRecords(records, for: Date())
    }

    func updateSettings(dailyGoal: Int? = nil, reminderEnabled: Bool? = nil, startHour: Int? = nil, interval: Int? = nil) {
        if let goal = dailyGoal {
            self.dailyGoal = goal
            storage.dailyGoal = goal
        }
        if let enabled = reminderEnabled {
            self.reminderEnabled = enabled
            storage.reminderEnabled = enabled
        }
        if let hour = startHour {
            self.reminderStartHour = hour
            storage.reminderStartHour = hour
        }
        if let mins = interval {
            self.reminderInterval = mins
            storage.reminderInterval = mins
        }
    }
}
