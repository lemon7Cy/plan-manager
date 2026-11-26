import Foundation
import Observation
import SwiftData

@Model
final class FitnessRecord {
    @Attribute(.unique) var key: String
    var payload: Data
    init(key: String, payload: Data) { self.key = key; self.payload = payload }
}

@MainActor
@Observable
final class FitnessStore {
    static let shared = FitnessStore()
    private(set) var archive = FitnessArchive()
    private(set) var revision = 0
    private(set) var storageError: String?
    @ObservationIgnored private var container: ModelContainer?

    init(inMemory: Bool = false, url: URL? = nil) {
        do {
            let configuration: ModelConfiguration
            if let url { configuration = ModelConfiguration("Fitness", url: url, cloudKitDatabase: .none) }
            else { configuration = ModelConfiguration("Fitness", isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none) }
            container = try ModelContainer(for: FitnessRecord.self, configurations: configuration)
            try reload()
        } catch {
            storageError = "健身数据读取失败，已暂停写入，原数据保留。\(error.localizedDescription)"
        }
    }

    private func reload() throws {
        guard let container else { throw FitnessIssue.invalid("本地数据库不可用。") }
        let records = try container.mainContext.fetch(FetchDescriptor<FitnessRecord>())
        let decoder = JSONDecoder()
        var loaded = FitnessArchive()
        for record in records {
            if record.key == "profile" { loaded.profile = try decoder.decode(FitnessProfile.self, from: record.payload) }
            else if record.key.hasPrefix("equipment:") { loaded.equipment.append(try decoder.decode(FitnessEquipment.self, from: record.payload)) }
            else if record.key.hasPrefix("plan:") { loaded.plans.append(try decoder.decode(FitnessPlan.self, from: record.payload)) }
            else if record.key.hasPrefix("session:") { loaded.sessions.append(try decoder.decode(FitnessSession.self, from: record.payload)) }
        }
        archive = loaded
    }

    private func commit(_ next: FitnessArchive) throws {
        guard storageError == nil, let container else { throw FitnessIssue.invalid(storageError ?? "本地数据库不可用。") }
        let context = container.mainContext
        context.autosaveEnabled = false
        let encoder = JSONEncoder()
        var values: [String: Data] = [:]
        if let profile = next.profile { values["profile"] = try encoder.encode(profile) }
        for item in next.equipment { values["equipment:\(item.id)"] = try encoder.encode(item) }
        for item in next.plans { values["plan:\(item.id)"] = try encoder.encode(item) }
        for item in next.sessions { values["session:\(item.id)"] = try encoder.encode(item) }
        do {
            for existing in try context.fetch(FetchDescriptor<FitnessRecord>()) {
                if let payload = values.removeValue(forKey: existing.key) {
                    if existing.payload != payload { existing.payload = payload }
                } else { context.delete(existing) }
            }
            for (key, data) in values { context.insert(FitnessRecord(key: key, payload: data)) }
            try context.save()
            archive = next
            revision += 1
        } catch {
            context.rollback()
            throw FitnessIssue.invalid("未能保存健身数据，请检查可用存储空间后重试。")
        }
    }

    func saveProfile(_ profile: FitnessProfile) throws {
        try profile.validate()
        var next = archive; next.profile = profile
        if profile != archive.profile {
            let completed = Set(next.sessions.map(\.id))
            next.plans.removeAll { $0.date >= Calendar.current.startOfDay(for: Date()) && !completed.contains($0.id) }
        }
        try commit(next)
    }

    func addEquipment(_ equipment: FitnessEquipment) throws {
        try equipment.validate()
        guard !archive.equipment.contains(where: { $0.id == equipment.id }) else { throw FitnessIssue.invalid("器材已经存在。") }
        var next = archive; next.equipment.append(equipment)
        try commit(next)
    }

    func toggleEquipment(_ id: UUID) throws {
        var next = archive
        guard let index = next.equipment.firstIndex(where: { $0.id == id }) else { return }
        next.equipment[index].active.toggle()
        if !next.equipment[index].active {
            let completed = Set(next.sessions.map(\.id))
            next.plans.removeAll { plan in !completed.contains(plan.id) && plan.exercises.contains { $0.equipment.id == id } }
        }
        try commit(next)
    }

    func savePlan(_ plan: FitnessPlan, expectedRevision: Int) throws {
        guard expectedRevision == revision else { throw FitnessIssue.invalid("生成期间档案或训练记录已变化，请按最新情况重新生成。") }
        guard !archive.sessions.contains(where: { Calendar.current.isDate($0.plan.date, inSameDayAs: plan.date) }) else {
            throw FitnessIssue.invalid("这一天已有完成记录，请保留训练历史。")
        }
        var next = archive
        next.plans.removeAll { Calendar.current.isDate($0.date, inSameDayAs: plan.date) }
        next.plans.append(plan)
        try commit(next)
    }

    func adoptSuggestedWeight(planID: UUID, exerciseID: UUID) throws {
        var next = archive
        guard let p = next.plans.firstIndex(where: { $0.id == planID }),
              !next.sessions.contains(where: { $0.id == planID }),
              let e = next.plans[p].exercises.firstIndex(where: { $0.id == exerciseID }),
              let suggestion = next.plans[p].exercises[e].suggestedWeight else { return }
        let exercise = next.plans[p].exercises[e]
        let current = FitnessPolicy.load(for: exercise.equipment, date: next.plans[p].date,
                                         fatigued: next.plans[p].readiness.fatigued, sessions: next.sessions)
        guard current.suggestion == suggestion else { throw FitnessIssue.invalid("训练记忆已变化，请重新生成计划。") }
        next.plans[p].exercises[e].weight = suggestion
        next.plans[p].exercises[e].suggestedWeight = nil
        next.plans[p].exercises[e].weightReason = "你选择了试加一个档位；若动作变形、疼痛或明显吃力，请立即减量。"
        try commit(next)
    }

    func finish(_ session: FitnessSession) throws {
        try session.validate()
        guard !archive.sessions.contains(where: { $0.id == session.id }) else { throw FitnessIssue.invalid("这份训练反馈已经保存，请勿重复提交。") }
        guard archive.plans.first(where: { $0.id == session.plan.id }) == session.plan else {
            throw FitnessIssue.invalid("计划已变化，请重新打开训练记录。")
        }
        var next = archive
        next.sessions.append(session)
        // Future uncompleted plans depend on the previous memory; invalidate them after real feedback.
        let finishedIDs = Set(next.sessions.map(\.id))
        next.plans.removeAll { $0.date > session.plan.date && !finishedIDs.contains($0.id) }
        try commit(next)
    }

    func recordManual(_ session: FitnessSession) throws {
        try session.validate()
        guard session.plan.source == "手动补记", !archive.sessions.contains(where: { $0.id == session.id }) else {
            throw FitnessIssue.invalid("补记训练无效或重复。")
        }
        var next = archive
        next.plans.append(session.plan); next.sessions.append(session)
        let finishedIDs = Set(next.sessions.map(\.id))
        next.plans.removeAll { $0.date > session.plan.date && !finishedIDs.contains($0.id) }
        try commit(next)
    }

    func exportArchive() throws -> FitnessArchive {
        guard storageError == nil else { throw FitnessIssue.invalid(storageError!) }
        return archive
    }

    func merge(_ imported: FitnessArchive) throws {
        guard imported.version == 1, imported.equipment.count <= 500, imported.plans.count <= 10000,
              imported.sessions.count <= 10000 else { throw FitnessIssue.invalid("健身备份版本或大小不受支持。") }
        try imported.profile?.validate()
        for item in imported.equipment { try item.validate() }
        guard Set(imported.equipment.map(\.id)).count == imported.equipment.count,
              Set(imported.plans.map(\.id)).count == imported.plans.count,
              Set(imported.sessions.map(\.id)).count == imported.sessions.count else { throw FitnessIssue.invalid("备份中有重复标识。") }
        for plan in imported.plans + imported.sessions.map(\.plan) {
            guard (0...23).contains(plan.startHour), (0...59).contains(plan.startMinute),
                  (0...90).contains(plan.availableMinutes), plan.summary.count <= 2000,
                  plan.exercises.count <= 5, Set(plan.exercises.map(\.id)).count == plan.exercises.count,
                  plan.date.timeIntervalSince1970.isFinite else { throw FitnessIssue.invalid("健身计划备份格式不正确。") }
            for exercise in plan.exercises {
                try exercise.equipment.validate()
                guard (1...4).contains(exercise.sets), (1...100).contains(exercise.reps),
                      (0...300).contains(exercise.restSeconds),
                      exercise.weight.map({ $0.isFinite && $0 > 0 && $0 <= 1100 }) ?? true,
                      exercise.suggestedWeight.map({ $0.isFinite && $0 > 0 && $0 <= 1100 }) ?? true else {
                    throw FitnessIssue.invalid("备份包含无效训练负荷。")
                }
            }
        }
        for session in imported.sessions { try session.validate() }
        var next = archive
        if let profile = imported.profile { next.profile = profile }
        next.equipment += imported.equipment.filter { item in !next.equipment.contains { $0.id == item.id } }
        next.plans += imported.plans.filter { item in !next.plans.contains { $0.id == item.id } }
        next.sessions += imported.sessions.filter { item in !next.sessions.contains { $0.id == item.id } }
        if next.profile != archive.profile || next.sessions.count != archive.sessions.count {
            let originalPlanIDs = Set(archive.plans.map(\.id)), completedIDs = Set(next.sessions.map(\.id))
            next.plans.removeAll { $0.date >= Calendar.current.startOfDay(for: Date()) && originalPlanIDs.contains($0.id) && !completedIDs.contains($0.id) }
        }
        try commit(next)
    }
}
