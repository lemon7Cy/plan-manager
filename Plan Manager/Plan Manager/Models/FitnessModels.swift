import Foundation

enum FitnessIssue: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest = "胸", back = "背", shoulders = "肩", legs = "腿", core = "核心"
    var id: String { rawValue }
}

enum FitnessMovement: String, Codable, CaseIterable, Identifiable {
    case chestPress = "坐姿推胸", latPull = "高位下拉", row = "坐姿划船"
    case shoulderPress = "坐姿推肩", legPress = "腿举", legCurl = "腿弯举"
    case squat = "徒手深蹲", deadBug = "死虫式"
    var id: String { rawValue }
    var muscles: Set<MuscleGroup> {
        switch self {
        case .chestPress: return [.chest, .shoulders]
        case .latPull, .row: return [.back]
        case .shoulderPress: return [.shoulders]
        case .legPress, .legCurl, .squat: return [.legs]
        case .deadBug: return [.core]
        }
    }
    var bodyweight: Bool { self == .squat || self == .deadBug }
}

enum FitnessSex: String, Codable, CaseIterable, Identifiable {
    case unspecified = "不填写", male = "男", female = "女"
    var id: String { rawValue }
}

struct FitnessProfile: Codable, Equatable {
    var heightCM = 170.0
    var weightKG = 65.0
    var age = 25
    var sex = FitnessSex.unspecified
    var waistCM: Double?
    var goal = "养成训练习惯"
    var beginner = true
    var trainingDays = [2, 4, 6] // Calendar weekday: Sunday = 1
    var startHour = 19
    var startMinute = 0
    var durationMinutes = 40
    var limitations = ""

    var bmi: Double { weightKG / pow(heightCM / 100, 2) }
    // Relative Fat Mass (RFM), adults only; not a clinical measurement.
    var estimatedBodyFat: Double? {
        guard age >= 18, sex != .unspecified, let waistCM, waistCM > 0 else { return nil }
        let value = 64 - 20 * heightCM / waistCM + (sex == .female ? 12 : 0)
        return (5...65).contains(value) ? value : nil
    }
    func validate() throws {
        guard heightCM.isFinite, (120...230).contains(heightCM),
              weightKG.isFinite, (30...250).contains(weightKG), (18...85).contains(age),
              (15...90).contains(durationMinutes), (0...23).contains(startHour),
              (0...59).contains(startMinute), !trainingDays.isEmpty,
              Set(trainingDays).count == trainingDays.count,
              trainingDays.allSatisfy({ (1...7).contains($0) }), limitations.count <= 500 else {
            throw FitnessIssue.invalid("请检查身体数据和训练时间。第一版适用于 18–85 岁成年人。")
        }
        if let waistCM, !waistCM.isFinite || !(40...200).contains(waistCM) {
            throw FitnessIssue.invalid("腰围应为 40–200 cm；不填写时不估测体脂。")
        }
    }
}

enum FitnessUnit: String, Codable, CaseIterable, Identifiable {
    case kg = "kg", lb = "lb"
    var id: String { rawValue }
}

enum LoadBasis: String, Codable, CaseIterable, Identifiable {
    case machine = "器械标示", single = "单只重量", total = "总重量"
    var id: String { rawValue }
}

struct FitnessEquipment: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var movement: FitnessMovement
    var unit = FitnessUnit.kg
    var basis = LoadBasis.machine
    var increment = 2.5
    var active = true
    var muscles: Set<MuscleGroup> { movement.muscles }
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 80,
              increment.isFinite, (0.25...25).contains(increment) else {
            throw FitnessIssue.invalid("请填写器材名称和有效的最小加重档位（0.25–25）。")
        }
    }
}

struct FitnessReadiness: Codable, Equatable {
    var soreMuscles: Set<MuscleGroup> = []
    var fatigued = false
    var hasPain = false
    var note = ""
}

struct FitnessExercise: Codable, Identifiable, Equatable {
    var id = UUID()
    var equipment: FitnessEquipment // Snapshot preserves unit and equipment identity.
    var sets: Int
    var reps: Int
    var restSeconds: Int
    var weight: Double?
    var suggestedWeight: Double?
    var weightReason: String
    var instructions: String
    var minutes: Int { Int(ceil(Double(sets * reps * 4 + sets * restSeconds + 60) / 60)) }
}

struct FitnessPlan: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var createdAt = Date()
    var startHour: Int
    var startMinute: Int
    var availableMinutes: Int
    var summary: String
    var exercises: [FitnessExercise]
    var readiness: FitnessReadiness
    var source = "GLM"
    var warmupMinutes: Int { exercises.isEmpty ? 0 : 5 }
    var cooldownMinutes: Int { exercises.isEmpty ? 0 : 5 }
    var durationMinutes: Int { exercises.reduce(warmupMinutes + cooldownMinutes) { $0 + $1.minutes } }
    var startDate: Date {
        Calendar.current.date(bySettingHour: startHour, minute: startMinute, second: 0, of: date) ?? date
    }
    func start(of exercise: FitnessExercise) -> Date {
        let preceding = exercises.prefix(while: { $0.id != exercise.id }).reduce(warmupMinutes) { $0 + $1.minutes }
        return startDate.addingTimeInterval(Double(preceding * 60))
    }
}

enum FitnessEffort: String, Codable, CaseIterable, Identifiable {
    case easy = "轻松", appropriate = "合适", hard = "吃力"
    var id: String { rawValue }
}

struct FitnessSet: Codable, Identifiable, Equatable {
    var id = UUID()
    var weight: Double?
    var reps = 0
    var completed = false
}

struct FitnessResult: Codable, Identifiable, Equatable {
    var id: UUID { exercise.id }
    var exercise: FitnessExercise
    var sets: [FitnessSet]
    var effort = FitnessEffort.appropriate
    var pain = false
    var note = ""

    var finished: [FitnessSet] { sets.filter(\.completed) }
    var qualifiedWeight: Double? {
        guard !pain, effort != .hard, finished.count >= exercise.sets,
              finished.allSatisfy({ $0.reps >= exercise.reps }),
              let weight = finished.first?.weight,
              finished.allSatisfy({ $0.weight == weight }) else { return nil }
        return weight
    }
    func validate() throws {
        guard sets.count == exercise.sets, note.count <= 500 else { throw FitnessIssue.invalid("训练组数或备注不正确。") }
        for set in finished {
            guard (1...100).contains(set.reps) else { throw FitnessIssue.invalid("请填写已完成组的实际次数（1–100）。") }
            if !exercise.equipment.movement.bodyweight {
                guard let weight = set.weight, weight.isFinite, weight > 0,
                      weight <= (exercise.equipment.unit == .kg ? 500 : 1100) else {
                    throw FitnessIssue.invalid("请填写已完成组的实际重量；未知重量不能作为训练记忆保存。")
                }
            }
        }
    }
}

struct FitnessSession: Codable, Identifiable, Equatable {
    var id: UUID { plan.id } // One final feedback record per plan.
    var plan: FitnessPlan
    var completedAt = Date()
    var results: [FitnessResult]
    var muscles: Set<MuscleGroup> {
        results.filter { !$0.finished.isEmpty }.reduce(into: []) { $0.formUnion($1.exercise.equipment.muscles) }
    }
    func validate() throws {
        guard results.map(\.exercise) == plan.exercises,
              results.contains(where: { !$0.finished.isEmpty || $0.pain }),
              plan.date <= Date() else { throw FitnessIssue.invalid("至少记录一组实际训练或疼痛反馈，不能提前完成未来计划。") }
        for result in results { try result.validate() }
    }
}

struct FitnessArchive: Codable, Equatable {
    var version = 1
    var profile: FitnessProfile?
    var equipment: [FitnessEquipment] = []
    var plans: [FitnessPlan] = []
    var sessions: [FitnessSession] = []
}

struct FitnessDraft: Decodable {
    struct Exercise: Decodable {
        var equipmentID: UUID
        var sets: Int
        var reps: Int
        var restSeconds: Int
        var instructions: String
    }
    var summary: String
    var exercises: [Exercise]
}
