//
//  LocalStorage.swift
//  Plan Manager
//
//  Local data persistence for water records
//

import Foundation

enum StorageKeys {
    static let nickname = "kCachedNickname"
    static let appTheme = "app_theme"
    static let plans = "offline_plans"
    static let expenses = "offline_expenses"
    static let nextPlanID = "offline_next_plan_id"
    static let nextExpenseID = "offline_next_expense_id"
    static let waterDailyGoal = "water_daily_goal"
    static let dailyReminderEnabled = "kDailyReminderEnabled"
    static let sleepReminderEnabled = "kSleepReminderEnabled"
    static let waterReminderEnabled = "kWaterReminderEnabled"
    static let hourlyReminderEnabled = "kHourlyReminderEnabled"
    static let dailyReminderTime = "kDailyReminderTime"
    static let sleepReminderTime = "kSleepReminderTime"
    static let waterStartHour = "kWaterStartHour"
    static let waterInterval = "kWaterInterval"
    static let waterReminderRandomSeed = "kWaterReminderRandomSeed"
}

extension Notification.Name {
    static let offlineDataDidChange = Notification.Name("offlineDataDidChange")
}

struct LocalProfile: Codable, Equatable {
    var nickname: String
}

struct OfflineSettings: Codable, Equatable {
    var theme: String
    var dailyGoal: Int
    var dailyReminderEnabled: Bool
    var sleepReminderEnabled: Bool
    var waterReminderEnabled: Bool
    var hourlyReminderEnabled: Bool
    var dailyReminderTime: Date?
    var sleepReminderTime: Date?
    var waterStartHour: Int
    var waterInterval: Int
}

struct PlanManagerBackup: Codable, Equatable {
    var schema: String
    var exportedAt: Date
    var appVersion: String
    var profile: LocalProfile
    var settings: OfflineSettings
    var plans: [Plan]
    var expenses: [Expense]
    var waterRecords: [String: [WaterRecord]]
    var fitness: FitnessArchive? = nil
}

struct BackupImportResult: Equatable {
    var importedPlans: Int
    var importedExpenses: Int
    var importedWaterRecords: Int
}

final class LocalStorage: @unchecked Sendable {
    static let shared = LocalStorage()

    private let userDefaults = UserDefaults.standard
    private let backupSchema = "plan_manager_backup_v1"

    private init() {}

    // MARK: - Profile

    var nickname: String {
        get {
            let value = userDefaults.string(forKey: StorageKeys.nickname) ?? "您"
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "您" : value
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            userDefaults.set(trimmed.isEmpty ? "您" : trimmed, forKey: StorageKeys.nickname)
        }
    }

    // MARK: - Plans

    func loadAllPlans() -> [Plan] {
        guard let data = userDefaults.data(forKey: StorageKeys.plans),
              let plans = try? JSONDecoder().decode([Plan].self, from: data) else {
            return []
        }
        return plans
    }

    func loadPlans(for date: Date) -> [Plan] {
        loadAllPlans()
            .filter { Calendar.current.isDate($0.executionDate, inSameDayAs: date) }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned
                }
                if lhs.isCompleted != rhs.isCompleted {
                    return !lhs.isCompleted
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    @discardableResult
    func createPlan(content: String, executionDate: Date, isPinned: Bool, tag: String) -> Plan {
        let plan = Plan(
            id: nextPlanID(),
            userId: 0,
            content: content,
            isPinned: isPinned,
            tag: tag,
            status: "pending",
            executionDate: executionDate,
            createdAt: Date(),
            updatedAt: nil
        )
        var plans = loadAllPlans()
        plans.insert(plan, at: 0)
        savePlans(plans)
        return plan
    }

    func updatePlan(_ plan: Plan) {
        var plans = loadAllPlans()
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
            savePlans(plans)
        }
    }

    func deletePlan(id: Int) {
        var plans = loadAllPlans()
        plans.removeAll { $0.id == id }
        savePlans(plans)
    }

    private func savePlans(_ plans: [Plan]) {
        if let data = try? JSONEncoder().encode(plans) {
            userDefaults.set(data, forKey: StorageKeys.plans)
        }
    }

    private func nextPlanID() -> Int {
        let stored = userDefaults.integer(forKey: StorageKeys.nextPlanID)
        let fallback = (loadAllPlans().map(\.id).max() ?? 0) + 1
        let next = max(stored, fallback)
        userDefaults.set(next + 1, forKey: StorageKeys.nextPlanID)
        return next
    }

    // MARK: - Expenses

    func loadExpenses() -> [Expense] {
        guard let data = userDefaults.data(forKey: StorageKeys.expenses),
              let expenses = try? JSONDecoder().decode([Expense].self, from: data) else {
            return []
        }
        return expenses.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func createExpense(amount: Double, category: String, note: String?) -> Expense {
        let expense = Expense(
            id: nextExpenseID(),
            userId: 0,
            amount: amount,
            category: category,
            note: note,
            createdAt: Date()
        )
        var expenses = loadExpenses()
        expenses.insert(expense, at: 0)
        saveExpenses(expenses)
        return expense
    }

    func deleteExpense(id: Int) {
        var expenses = loadExpenses()
        expenses.removeAll { $0.id == id }
        saveExpenses(expenses)
    }

    private func saveExpenses(_ expenses: [Expense]) {
        if let data = try? JSONEncoder().encode(expenses) {
            userDefaults.set(data, forKey: StorageKeys.expenses)
        }
    }

    private func nextExpenseID() -> Int {
        let stored = userDefaults.integer(forKey: StorageKeys.nextExpenseID)
        let fallback = (loadExpenses().compactMap(\.id).max() ?? 0) + 1
        let next = max(stored, fallback)
        userDefaults.set(next + 1, forKey: StorageKeys.nextExpenseID)
        return next
    }

    // MARK: - Water Records

    private func waterRecordsKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "water_records_\(formatter.string(from: date))"
    }

    func saveWaterRecords(_ records: [WaterRecord], for date: Date) {
        if let data = try? JSONEncoder().encode(records) {
            userDefaults.set(data, forKey: waterRecordsKey(for: date))
        }
    }

    func loadWaterRecords(for date: Date) -> [WaterRecord] {
        guard let data = userDefaults.data(forKey: waterRecordsKey(for: date)),
              let records = try? JSONDecoder().decode([WaterRecord].self, from: data) else {
            return []
        }
        return records
    }

    func loadAllWaterRecordsByDate() -> [String: [WaterRecord]] {
        var result: [String: [WaterRecord]] = [:]
        for key in userDefaults.dictionaryRepresentation().keys where key.hasPrefix("water_records_") {
            let dateKey = String(key.dropFirst("water_records_".count))
            guard let data = userDefaults.data(forKey: key),
                  let records = try? JSONDecoder().decode([WaterRecord].self, from: data) else {
                continue
            }
            result[dateKey] = records
        }
        return result
    }

    private func saveWaterRecords(_ recordsByDate: [String: [WaterRecord]]) {
        for (dateKey, records) in recordsByDate {
            if let data = try? JSONEncoder().encode(records) {
                userDefaults.set(data, forKey: "water_records_\(dateKey)")
            }
        }
    }

    // MARK: - Water Settings

    var dailyGoal: Int {
        get { userDefaults.integer(forKey: StorageKeys.waterDailyGoal).nonZero ?? 2000 }
        set { userDefaults.set(newValue, forKey: StorageKeys.waterDailyGoal) }
    }

    var reminderEnabled: Bool {
        get { userDefaults.bool(forKey: "water_reminder_enabled") }
        set { userDefaults.set(newValue, forKey: "water_reminder_enabled") }
    }

    var reminderStartHour: Int {
        get { userDefaults.integer(forKey: "water_start_hour").nonZero ?? 8 }
        set { userDefaults.set(newValue, forKey: "water_start_hour") }
    }

    var reminderInterval: Int {
        get { userDefaults.integer(forKey: "water_interval").nonZero ?? 60 }
        set { userDefaults.set(newValue, forKey: "water_interval") }
    }

    // MARK: - Backup

    @MainActor
    func makeBackup(appVersion: String) throws -> PlanManagerBackup {
        PlanManagerBackup(
            schema: backupSchema,
            exportedAt: Date(),
            appVersion: appVersion,
            profile: LocalProfile(nickname: nickname),
            settings: currentSettings(),
            plans: loadAllPlans(),
            expenses: loadExpenses(),
            waterRecords: loadAllWaterRecordsByDate(),
            fitness: try FitnessStore.shared.exportArchive()
        )
    }

    @MainActor
    func encodedBackup(appVersion: String) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(makeBackup(appVersion: appVersion))
    }

    @MainActor
    func importBackup(data: Data) throws -> BackupImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(PlanManagerBackup.self, from: data)
        guard backup.schema == backupSchema else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Validate and commit fitness first; malformed fitness cannot partially overwrite legacy settings.
        if let fitness = backup.fitness { try FitnessStore.shared.merge(fitness) }

        nickname = backup.profile.nickname
        applySettings(backup.settings)

        let importedPlans = mergePlans(backup.plans)
        let importedExpenses = mergeExpenses(backup.expenses)
        let importedWaterRecords = mergeWaterRecords(backup.waterRecords)

        NotificationCenter.default.post(name: .offlineDataDidChange, object: nil)
        return BackupImportResult(
            importedPlans: importedPlans,
            importedExpenses: importedExpenses,
            importedWaterRecords: importedWaterRecords
        )
    }

    private func currentSettings() -> OfflineSettings {
        OfflineSettings(
            theme: userDefaults.string(forKey: StorageKeys.appTheme) ?? AppTheme.dark.rawValue,
            dailyGoal: dailyGoal,
            dailyReminderEnabled: userDefaults.bool(forKey: StorageKeys.dailyReminderEnabled),
            sleepReminderEnabled: userDefaults.bool(forKey: StorageKeys.sleepReminderEnabled),
            waterReminderEnabled: userDefaults.bool(forKey: StorageKeys.waterReminderEnabled),
            hourlyReminderEnabled: userDefaults.bool(forKey: StorageKeys.hourlyReminderEnabled),
            dailyReminderTime: userDefaults.object(forKey: StorageKeys.dailyReminderTime) as? Date,
            sleepReminderTime: userDefaults.object(forKey: StorageKeys.sleepReminderTime) as? Date,
            waterStartHour: userDefaults.integer(forKey: StorageKeys.waterStartHour).nonZero ?? 9,
            waterInterval: userDefaults.integer(forKey: StorageKeys.waterInterval).nonZero ?? 120
        )
    }

    private func applySettings(_ settings: OfflineSettings) {
        userDefaults.set(settings.theme, forKey: StorageKeys.appTheme)
        dailyGoal = settings.dailyGoal
        userDefaults.set(settings.dailyReminderEnabled, forKey: StorageKeys.dailyReminderEnabled)
        userDefaults.set(settings.sleepReminderEnabled, forKey: StorageKeys.sleepReminderEnabled)
        userDefaults.set(settings.waterReminderEnabled, forKey: StorageKeys.waterReminderEnabled)
        userDefaults.set(settings.hourlyReminderEnabled, forKey: StorageKeys.hourlyReminderEnabled)
        if let dailyReminderTime = settings.dailyReminderTime {
            userDefaults.set(dailyReminderTime, forKey: StorageKeys.dailyReminderTime)
        }
        if let sleepReminderTime = settings.sleepReminderTime {
            userDefaults.set(sleepReminderTime, forKey: StorageKeys.sleepReminderTime)
        }
        userDefaults.set(settings.waterStartHour, forKey: StorageKeys.waterStartHour)
        userDefaults.set(settings.waterInterval, forKey: StorageKeys.waterInterval)
    }

    private func mergePlans(_ importedPlans: [Plan]) -> Int {
        var plans = loadAllPlans()
        var keys = Set(plans.map(planDedupKey))
        var importedCount = 0

        for plan in importedPlans {
            let key = planDedupKey(plan)
            guard !keys.contains(key) else { continue }
            let localPlan = Plan(
                id: nextPlanID(),
                userId: 0,
                content: plan.content,
                isPinned: plan.isPinned,
                tag: plan.tag,
                status: plan.status,
                executionDate: plan.executionDate,
                createdAt: plan.createdAt,
                updatedAt: plan.updatedAt
            )
            plans.append(localPlan)
            keys.insert(key)
            importedCount += 1
        }

        savePlans(plans)
        return importedCount
    }

    private func mergeExpenses(_ importedExpenses: [Expense]) -> Int {
        var expenses = loadExpenses()
        var keys = Set(expenses.map(expenseDedupKey))
        var importedCount = 0

        for expense in importedExpenses {
            let key = expenseDedupKey(expense)
            guard !keys.contains(key) else { continue }
            let localExpense = Expense(
                id: nextExpenseID(),
                userId: 0,
                amount: expense.amount,
                category: expense.category,
                note: expense.note,
                createdAt: expense.createdAt
            )
            expenses.append(localExpense)
            keys.insert(key)
            importedCount += 1
        }

        saveExpenses(expenses)
        return importedCount
    }

    private func mergeWaterRecords(_ imported: [String: [WaterRecord]]) -> Int {
        var current = loadAllWaterRecordsByDate()
        var importedCount = 0

        for (dateKey, records) in imported {
            var existing = current[dateKey] ?? []
            var idKeys = Set(existing.map { $0.id.uuidString })
            var fallbackKeys = Set(existing.map(waterRecordDedupKey))

            for record in records {
                let idKey = record.id.uuidString
                let fallbackKey = waterRecordDedupKey(record)
                guard !idKeys.contains(idKey), !fallbackKeys.contains(fallbackKey) else { continue }
                existing.append(record)
                idKeys.insert(idKey)
                fallbackKeys.insert(fallbackKey)
                importedCount += 1
            }

            current[dateKey] = existing.sorted { $0.time > $1.time }
        }

        saveWaterRecords(current)
        return importedCount
    }

    private func planDedupKey(_ plan: Plan) -> String {
        [
            plan.content.trimmingCharacters(in: .whitespacesAndNewlines),
            dayKey(for: plan.executionDate),
            plan.isPinned ? "pinned" : "normal",
            plan.tag.trimmingCharacters(in: .whitespacesAndNewlines),
            plan.status,
            timestampKey(plan.createdAt)
        ].joined(separator: "|")
    }

    private func expenseDedupKey(_ expense: Expense) -> String {
        [
            String(format: "%.2f", expense.amount),
            expense.category.trimmingCharacters(in: .whitespacesAndNewlines),
            expense.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            timestampKey(expense.createdAt)
        ].joined(separator: "|")
    }

    private func waterRecordDedupKey(_ record: WaterRecord) -> String {
        [
            record.type,
            "\(record.amount)",
            record.iconName,
            record.colorHex,
            timestampKey(record.time)
        ].joined(separator: "|")
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func timestampKey(_ date: Date) -> String {
        String(Int((date.timeIntervalSince1970 * 1000).rounded()))
    }
}

// MARK: - Helper Extension

extension Int {
    var nonZero: Int? {
        self == 0 ? nil : self
    }
}
