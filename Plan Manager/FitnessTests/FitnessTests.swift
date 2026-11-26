import XCTest
#if canImport(Plan_Manager)
@testable import Plan_Manager
#else
@testable import FitnessCore
#endif

@MainActor
final class FitnessTests: XCTestCase {
    let machine = FitnessEquipment(name: "A 区推胸机", movement: .chestPress, increment: 1)
    func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date()))!
    }
    func session(_ offset: Int, equipment: FitnessEquipment? = nil, weight: Double = 10,
                 effort: FitnessEffort = .easy, pain: Bool = false, complete: Bool = true) -> FitnessSession {
        let exercise = FitnessExercise(equipment: equipment ?? machine, sets: 2, reps: 10, restSeconds: 90,
                                       weight: weight, suggestedWeight: nil, weightReason: "test", instructions: "保持动作稳定")
        let plan = FitnessPlan(date: day(offset), startHour: 19, startMinute: 0, availableMinutes: 40,
                               summary: "测试计划", exercises: [exercise], readiness: FitnessReadiness(), source: "手动补记")
        let result = FitnessResult(exercise: exercise, sets: [FitnessSet(weight: weight, reps: 10, completed: true),
                                                             FitnessSet(weight: weight, reps: 10, completed: complete)],
                                   effort: effort, pain: pain)
        return FitnessSession(plan: plan, results: [result])
    }
    func archive(sessions: [FitnessSession] = []) -> FitnessArchive {
        var profile = FitnessProfile(); profile.trainingDays = Array(1...7)
        return FitnessArchive(profile: profile, equipment: [machine], sessions: sessions)
    }
    func draft(equipment: FitnessEquipment? = nil) -> FitnessDraft {
        FitnessDraft(summary: "安排上肢训练", exercises: [FitnessDraft.Exercise(equipmentID: (equipment ?? machine).id,
                                                                          sets: 2, reps: 10, restSeconds: 90, instructions: "平稳控制，疼痛停止")])
    }

    func testBodyMetricsAndInvalidInput() async throws {
        var profile = FitnessProfile(); profile.heightCM = 180; profile.weightKG = 81
        XCTAssertEqual(profile.bmi, 25, accuracy: 0.001)
        XCTAssertNil(profile.estimatedBodyFat)
        profile.waistCM = 90; profile.sex = .male
        XCTAssertEqual(profile.estimatedBodyFat!, 24, accuracy: 0.001)
        profile.age = 12; XCTAssertThrowsError(try profile.validate())
        profile.age = 25; profile.weightKG = .nan; XCTAssertThrowsError(try profile.validate())
    }

    func testYesterdayLegsAndCurrentSorenessBlocked() async throws {
        let legs = FitnessEquipment(name: "腿举", movement: .legPress)
        var data = archive(sessions: [session(-1, equipment: legs)])
        data.equipment.append(legs)
        let readiness = FitnessReadiness(soreMuscles: [.chest])
        XCTAssertTrue(FitnessPolicy.availableEquipment(archive: data, date: day(0), readiness: readiness).isEmpty)
        XCTAssertThrowsError(try FitnessPolicy.makePlan(draft: draft(equipment: legs), archive: data, date: day(0), readiness: FitnessReadiness()))
    }

    func testUnknownWeightAndSingleFeedbackNeverIncrease() async {
        XCTAssertNil(FitnessPolicy.load(for: machine, date: day(0), fatigued: false, sessions: []).weight)
        let load = FitnessPolicy.load(for: machine, date: day(0), fatigued: false, sessions: [session(-3)])
        XCTAssertEqual(load.weight, 10); XCTAssertNil(load.suggestion)
    }

    func testTwoDistinctSuccessfulDaysOfferOneSmallIncrement() async {
        let load = FitnessPolicy.load(for: machine, date: day(0), fatigued: false, sessions: [session(-3), session(-6)])
        XCTAssertEqual(load.weight, 10); XCTAssertEqual(load.suggestion, 11)
        let sameDay = FitnessPolicy.load(for: machine, date: day(0), fatigued: false, sessions: [session(-3), session(-3)])
        XCTAssertNil(sameDay.suggestion)
    }

    func testLargeMachineStepAndDifferentUnitsDoNotIncrease() async {
        var largeStep = machine; largeStep.increment = 5
        XCTAssertNil(FitnessPolicy.load(for: largeStep, date: day(0), fatigued: false, sessions: [session(-3), session(-6)]).suggestion)
        var pounds = machine; pounds.unit = .lb
        XCTAssertNil(FitnessPolicy.load(for: pounds, date: day(0), fatigued: false, sessions: [session(-3)]).weight)
        var other = machine; other.id = UUID()
        XCTAssertNil(FitnessPolicy.load(for: other, date: day(0), fatigued: false, sessions: [session(-3)]).weight)
    }

    func testPainFailureFatigueStaleHistoryDoNotPromote() async {
        XCTAssertNil(FitnessPolicy.load(for: machine, date: day(0), fatigued: false, sessions: [session(-3, pain: true), session(-6)]).weight)
        let failed = FitnessPolicy.load(for: machine, date: day(0), fatigued: false, sessions: [session(-3, complete: false), session(-6)])
        XCTAssertEqual(failed.weight, 8); XCTAssertNil(failed.suggestion)
        let tired = FitnessPolicy.load(for: machine, date: day(0), fatigued: true, sessions: [session(-3), session(-6)])
        XCTAssertEqual(tired.weight, 8); XCTAssertNil(tired.suggestion)
        XCTAssertNil(FitnessPolicy.load(for: machine, date: day(0), fatigued: false, sessions: [session(-31)]).weight)
    }

    func testDraftRejectsUnknownDuplicateExtremeAndOvertime() async throws {
        let good = try FitnessPolicy.makePlan(draft: draft(), archive: archive(), date: day(0), readiness: FitnessReadiness())
        XCTAssertNil(good.exercises[0].weight)
        var bad = draft(); bad.exercises[0].equipmentID = UUID()
        XCTAssertThrowsError(try FitnessPolicy.makePlan(draft: bad, archive: archive(), date: day(0), readiness: FitnessReadiness()))
        bad = draft(); bad.exercises.append(bad.exercises[0])
        XCTAssertThrowsError(try FitnessPolicy.makePlan(draft: bad, archive: archive(), date: day(0), readiness: FitnessReadiness()))
        bad = draft(); bad.exercises[0].sets = 10
        XCTAssertThrowsError(try FitnessPolicy.makePlan(draft: bad, archive: archive(), date: day(0), readiness: FitnessReadiness()))
        var short = archive(); short.profile?.durationMinutes = 15
        bad = draft(); bad.exercises[0].sets = 3; bad.exercises[0].restSeconds = 180
        XCTAssertThrowsError(try FitnessPolicy.makePlan(draft: bad, archive: short, date: day(0), readiness: FitnessReadiness()))
    }

    func testPainAndRestDaysGenerateLocally() async {
        XCTAssertNotNil(FitnessPolicy.restPlan(archive: archive(), date: day(0), readiness: FitnessReadiness(hasPain: true)))
        var data = archive(); data.profile?.trainingDays = [Calendar.current.component(.weekday, from: day(1))]
        XCTAssertNotNil(FitnessPolicy.restPlan(archive: data, date: day(0), readiness: FitnessReadiness()))
    }

    func testTruncatedMalformedAndHTTPErrorNeverBecomePlans() async throws {
        let body: [String: Any] = ["choices": [["finish_reason": "length", "message": ["content": "{}"]]]]
        XCTAssertThrowsError(try FitnessLLM.decode(JSONSerialization.data(withJSONObject: body), status: 200))
        XCTAssertThrowsError(try FitnessLLM.decode(Data("not json".utf8), status: 200))
        XCTAssertThrowsError(try FitnessLLM.decode(Data(), status: 401))
        XCTAssertThrowsError(try FitnessLLM.decode(Data(), status: 429))
    }

    func testRequestUsesSpecifiedModelAndNoThinkingOrUnrelatedData() async throws {
        let body = try FitnessLLM.requestBody(archive: archive(sessions: [session(-3)]), date: day(0),
                                              readiness: FitnessReadiness(), settings: FitnessLLMSettings())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(object["model"] as? String, "glm-5.3-flash")
        XCTAssertEqual((object["thinking"] as? [String: String])?["type"], "disabled")
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertFalse(text.contains("Authorization")); XCTAssertFalse(text.contains("offline_expenses"))
        XCTAssertThrowsError(try FitnessLLMSettings().endpoint())
        XCTAssertEqual(try FitnessLLMSettings(baseURL: "https://api.example.com/").endpoint().path, "/v1/chat/completions")
        XCTAssertEqual(try FitnessLLMSettings(baseURL: "http://localhost:8080/").endpoint().path, "/v1/chat/completions")
        XCTAssertThrowsError(try FitnessLLMSettings(baseURL: "http://other.example/v1").endpoint())
        XCTAssertThrowsError(try FitnessLLMSettings(baseURL: "https://user:password@example.com/v1").endpoint())
    }

    func testStoreRejectsStaleGenerationAndDuplicateFeedback() async throws {
        let store = FitnessStore(inMemory: true)
        try store.saveProfile(FitnessProfile()); try store.addEquipment(machine)
        let old = store.revision
        try store.toggleEquipment(machine.id)
        XCTAssertThrowsError(try store.savePlan(session(0).plan, expectedRevision: old))
        let completed = session(0)
        try store.savePlan(completed.plan, expectedRevision: store.revision)
        try store.finish(completed)
        XCTAssertThrowsError(try store.finish(completed))
        XCTAssertEqual(store.archive.sessions.count, 1)
    }

    func testFeedbackInvalidatesOnlyUncompletedFuturePlans() async throws {
        let store = FitnessStore(inMemory: true)
        let today = session(0), tomorrow = session(1)
        try store.savePlan(today.plan, expectedRevision: store.revision)
        try store.savePlan(tomorrow.plan, expectedRevision: store.revision)
        try store.finish(today)
        XCTAssertEqual(store.archive.plans.map(\.id), [today.id])
    }

    func testBackupRoundtripIdempotenceAndAtomicRejection() async throws {
        let store = FitnessStore(inMemory: true)
        var data = archive(sessions: [session(-3)])
        data.plans = data.sessions.map(\.plan)
        try store.merge(data); try store.merge(data)
        XCTAssertEqual(store.archive.sessions.count, 1); XCTAssertEqual(store.archive.equipment.count, 1)
        let encoded = try JSONEncoder().encode(store.exportArchive())
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("apiKey"))
        let restored = FitnessStore(inMemory: true)
        try restored.merge(JSONDecoder().decode(FitnessArchive.self, from: encoded))
        XCTAssertEqual(restored.archive, store.archive)
        var invalid = data; invalid.equipment[0].increment = -1
        XCTAssertThrowsError(try restored.merge(invalid)); XCTAssertEqual(restored.archive, store.archive)
    }

    #if canImport(Plan_Manager)
    func testOldBackupDecodesWithoutFitness() async throws {
        let old = PlanManagerBackup(schema: "plan_manager_backup_v1", exportedAt: Date(), appVersion: "1.60",
                                    profile: LocalProfile(nickname: "test"),
                                    settings: OfflineSettings(theme: "dark", dailyGoal: 2000, dailyReminderEnabled: false,
                                                              sleepReminderEnabled: false, waterReminderEnabled: false,
                                                              hourlyReminderEnabled: false, dailyReminderTime: nil,
                                                              sleepReminderTime: nil, waterStartHour: 9, waterInterval: 120),
                                    plans: [], expenses: [], waterRecords: [:])
        let encoded = try JSONEncoder().encode(old)
        XCTAssertNil(try JSONDecoder().decode(PlanManagerBackup.self, from: encoded).fitness)
    }
    #endif

    func testFeedbackRequiresActualWeightAndMatchingExercise() async throws {
        var data = session(0); data.results[0].sets[0].weight = nil
        XCTAssertThrowsError(try data.validate())
        data = session(0); data.results[0].exercise.reps = 1
        XCTAssertThrowsError(try data.validate())
    }

    func testProfileAndEquipmentChangesInvalidatePendingPlans() async throws {
        let store = FitnessStore(inMemory: true)
        try store.saveProfile(FitnessProfile()); try store.addEquipment(machine)
        try store.savePlan(session(0).plan, expectedRevision: store.revision)
        var changed = FitnessProfile(); changed.durationMinutes = 20
        try store.saveProfile(changed)
        XCTAssertTrue(store.archive.plans.isEmpty)
        try store.savePlan(session(0).plan, expectedRevision: store.revision)
        try store.toggleEquipment(machine.id)
        XCTAssertTrue(store.archive.plans.isEmpty)
    }

    func testDiskPersistenceAcrossStoreRecreation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Fitness.store")
        let saved = session(-3)
        do {
            let first = FitnessStore(url: url)
            XCTAssertNil(first.storageError)
            try first.saveProfile(FitnessProfile()); try first.addEquipment(machine)
            try first.recordManual(saved)
        }
        let reopened = FitnessStore(url: url)
        XCTAssertNil(reopened.storageError)
        XCTAssertEqual(reopened.archive.profile, FitnessProfile())
        XCTAssertEqual(reopened.archive.sessions, [saved])
        XCTAssertEqual(reopened.archive.equipment, [machine])
    }

    func testCorruptBackupDoesNotOverwriteExistingProfile() async throws {
        let store = FitnessStore(inMemory: true)
        try store.saveProfile(FitnessProfile())
        var corrupt = archive(sessions: [session(-3)])
        corrupt.profile?.weightKG = 100
        corrupt.sessions[0].results[0].sets[0].weight = nil
        XCTAssertThrowsError(try store.merge(corrupt))
        XCTAssertEqual(store.archive.profile, FitnessProfile())
        XCTAssertTrue(store.archive.sessions.isEmpty)
    }

    func testLiveGatewayWhenLocalCredentialPresent() async throws {
        // Optional local smoke fixture, outside the repository; never included in the build or logs.
        let path = "/tmp/plan-manager-fitness-live-key"
        guard let data = FileManager.default.contents(atPath: path),
              let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty,
              let baseURL = ProcessInfo.processInfo.environment["FITNESS_LIVE_BASE_URL"], !baseURL.isEmpty else {
            throw XCTSkip("No local live gateway credential fixture")
        }
        let result = try await FitnessLLM.generate(archive: archive(sessions: [session(-3)]), date: day(0),
                                                   readiness: FitnessReadiness(),
                                                   settings: FitnessLLMSettings(baseURL: baseURL), key: key)
        XCTAssertEqual(result.exercises.count, 1)
        XCTAssertEqual(result.exercises.first?.weight, 10)
        XCTAssertNil(result.exercises.first?.suggestedWeight)
        XCTAssertLessThanOrEqual(result.durationMinutes, 40)
    }
}
