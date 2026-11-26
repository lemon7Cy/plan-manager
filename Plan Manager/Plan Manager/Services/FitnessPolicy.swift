import Foundation

enum FitnessPolicy {
    static func blockedMuscles(on date: Date, readiness: FitnessReadiness, sessions: [FitnessSession]) -> Set<MuscleGroup> {
        var blocked = readiness.soreMuscles
        for session in sessions {
            // Compare local calendar days, so the same dates behave consistently at midnight and DST changes.
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: session.plan.date), to: Calendar.current.startOfDay(for: date)).day ?? -1
            guard days >= 0 else { continue }
            if days < 2 { blocked.formUnion(session.muscles) }
            if days < 3 {
                for result in session.results where result.pain { blocked.formUnion(result.exercise.equipment.muscles) }
            }
        }
        return blocked
    }

    static func availableEquipment(archive: FitnessArchive, date: Date, readiness: FitnessReadiness) -> [FitnessEquipment] {
        guard !readiness.hasPain else { return [] }
        let blocked = blockedMuscles(on: date, readiness: readiness, sessions: archive.sessions)
        return archive.equipment.filter { $0.active && $0.muscles.isDisjoint(with: blocked) }
    }

    static func load(for equipment: FitnessEquipment, date: Date, fatigued: Bool, sessions: [FitnessSession]) -> (weight: Double?, suggestion: Double?, reason: String) {
        if equipment.movement.bodyweight { return (nil, nil, "徒手动作，以动作稳定和舒适为准。") }
        let history = sessions.filter { $0.plan.date < date && date.timeIntervalSince($0.plan.date) <= 30 * 86400 }
            .sorted { $0.plan.date > $1.plan.date }
            .compactMap { session -> (Date, FitnessResult)? in
                guard let result = session.results.first(where: {
                    $0.exercise.equipment.id == equipment.id && $0.exercise.equipment.unit == equipment.unit &&
                    $0.exercise.equipment.basis == equipment.basis && (!$0.finished.isEmpty || $0.pain)
                }) else { return nil }
                return (session.plan.date, result)
            }
        guard let latest = history.first?.1 else {
            return (nil, nil, "近 30 天没有这台器材的有效记录。先轻重量试做，留下约 3 次余力，再记录实际重量。")
        }
        guard !latest.pain else { return (nil, nil, "上次报告疼痛。确认已恢复后重新轻重量试做，不沿用原负重。") }
        guard let baseline = latest.qualifiedWeight else {
            let lightest = latest.finished.compactMap(\.weight).min()
            let reduced = lightest.map { floor($0 * 0.8 / equipment.increment) * equipment.increment }
            return (reduced.flatMap { $0 > 0 ? $0 : nil }, nil, "上次吃力或未完成目标，降低负荷重新确认，不自动加重。")
        }
        if fatigued {
            let lighter = floor(baseline * 0.8 / equipment.increment) * equipment.increment
            return (lighter > 0 ? lighter : nil, nil, "今天疲劳，先降低负荷并减少训练组数。")
        }
        let two = Array(history.prefix(2))
        let differentDays = two.count == 2 && !Calendar.current.isDate(two[0].0, inSameDayAs: two[1].0)
        let canIncrease = differentDays && two.allSatisfy { $0.1.effort == .easy && $0.1.qualifiedWeight == baseline }
            && equipment.increment / baseline <= 0.10
        if differentDays && two.allSatisfy({ $0.1.effort == .easy && $0.1.qualifiedWeight == baseline }) && equipment.increment / baseline > 0.10 {
            return (baseline, nil, "这台器材最小增量超过当前重量的 10%。先稳住动作与次数，或使用更细的档位，不直接跳档。")
        }
        return (baseline, canIncrease ? baseline + equipment.increment : nil,
                canIncrease ? "两次不同日期都完成目标且轻松无痛。默认保持原重量，可自行选择试加一个档位。" : "沿用最近验证过的重量。连续两次完成目标且轻松无痛后，才考虑小幅加重。")
    }

    static func makePlan(draft: FitnessDraft, archive: FitnessArchive, date: Date, readiness: FitnessReadiness) throws -> FitnessPlan {
        guard let profile = archive.profile else { throw FitnessIssue.invalid("请先保存身体档案。") }
        try profile.validate()
        guard !readiness.hasPain, !draft.summary.isEmpty, draft.summary.count <= 1200,
              (0...5).contains(draft.exercises.count),
              Set(draft.exercises.map(\.equipmentID)).count == draft.exercises.count else {
            throw FitnessIssue.invalid("模型返回的计划不完整或重复，请重新生成。原计划已保留。")
        }
        let allowed = availableEquipment(archive: archive, date: date, readiness: readiness)
        var exercises: [FitnessExercise] = []
        for item in draft.exercises {
            guard let equipment = allowed.first(where: { $0.id == item.equipmentID }),
                  (1...(readiness.fatigued ? 2 : (profile.beginner ? 3 : 4))).contains(item.sets),
                  (8...15).contains(item.reps), (60...180).contains(item.restSeconds),
                  !item.instructions.isEmpty, item.instructions.count <= 700 else {
                throw FitnessIssue.invalid("计划包含不可用器材、未恢复肌群或不合适的训练量，已拒绝保存。")
            }
            let weight = load(for: equipment, date: date, fatigued: readiness.fatigued, sessions: archive.sessions)
            exercises.append(FitnessExercise(equipment: equipment, sets: item.sets, reps: item.reps,
                                            restSeconds: item.restSeconds, weight: weight.weight,
                                            suggestedWeight: weight.suggestion, weightReason: weight.reason,
                                            instructions: item.instructions))
        }
        let plan = FitnessPlan(date: Calendar.current.startOfDay(for: date), startHour: profile.startHour,
                               startMinute: profile.startMinute, availableMinutes: profile.durationMinutes,
                               summary: draft.summary, exercises: exercises, readiness: readiness)
        guard plan.durationMinutes <= profile.durationMinutes else {
            throw FitnessIssue.invalid("计划超过可用时长（已计入热身、组间休息和放松），请重新生成。")
        }
        return plan
    }

    static func restPlan(archive: FitnessArchive, date: Date, readiness: FitnessReadiness) -> FitnessPlan? {
        guard let profile = archive.profile else { return nil }
        var reason: String?
        if readiness.hasPain { reason = "今天有疼痛反馈，先暂停负重训练。若疼痛持续或加重，先咨询专业人员。" }
        else if !profile.trainingDays.contains(Calendar.current.component(.weekday, from: date)) { reason = "今天是你设置的休息日。按舒适程度散步，优先睡眠和恢复。" }
        else if availableEquipment(archive: archive, date: date, readiness: readiness).isEmpty { reason = "现有器材对应的肌群仍需恢复，或尚未添加可用器材。今天安排休息，也可以先完善器材档案。" }
        guard let reason else { return nil }
        return FitnessPlan(date: Calendar.current.startOfDay(for: date), startHour: profile.startHour,
                           startMinute: profile.startMinute, availableMinutes: profile.durationMinutes,
                           summary: reason, exercises: [], readiness: readiness, source: "本地恢复规则")
    }
}
